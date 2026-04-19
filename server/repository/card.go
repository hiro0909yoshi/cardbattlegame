package repository

import (
	"context"
	"encoding/json"
	"fmt"

	"arcana-conquest-server/model"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type CardRepo struct {
	pool *pgxpool.Pool
}

func NewCardRepo(pool *pgxpool.Pool) *CardRepo {
	return &CardRepo{pool: pool}
}

// --- UserCards ---

func (r *CardRepo) UpsertCard(ctx context.Context, userID int64, cardID, count, level int) error {
	if _, err := r.pool.Exec(ctx, `
		INSERT INTO user_cards (user_id, card_id, count, card_level, obtained)
		VALUES ($1, $2, $3, $4, TRUE)
		ON CONFLICT (user_id, card_id) DO UPDATE SET count=$3, card_level=$4, obtained=TRUE`,
		userID, cardID, count, level); err != nil {
		return fmt.Errorf("upsert card %d for user %d: %w", cardID, userID, err)
	}
	return nil
}

func (r *CardRepo) GetCards(ctx context.Context, userID int64) ([]model.UserCard, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT user_id, card_id, count, card_level, obtained
		FROM user_cards WHERE user_id=$1`, userID)
	if err != nil {
		return nil, fmt.Errorf("get cards %d: %w", userID, err)
	}
	defer rows.Close()

	var cards []model.UserCard
	for rows.Next() {
		var c model.UserCard
		if err := rows.Scan(&c.UserID, &c.CardID, &c.Count, &c.Level, &c.Obtained); err != nil {
			return nil, err
		}
		cards = append(cards, c)
	}
	return cards, rows.Err()
}

func (r *CardRepo) RemoveCard(ctx context.Context, userID int64, cardID, amount int) error {
	if _, err := r.pool.Exec(ctx, `
		UPDATE user_cards SET count = GREATEST(count - $3, 0)
		WHERE user_id=$1 AND card_id=$2`, userID, cardID, amount); err != nil {
		return fmt.Errorf("remove card %d for user %d: %w", cardID, userID, err)
	}
	return nil
}

// --- Decks ---

func (r *CardRepo) UpsertDeck(ctx context.Context, userID int64, slot int, name string, cards json.RawMessage) error {
	if _, err := r.pool.Exec(ctx, `
		INSERT INTO decks (user_id, slot_index, deck_name, cards, updated_at)
		VALUES ($1, $2, $3, $4, NOW())
		ON CONFLICT (user_id, slot_index) DO UPDATE SET deck_name=$3, cards=$4, updated_at=NOW()`,
		userID, slot, name, cards); err != nil {
		return fmt.Errorf("upsert deck slot %d for user %d: %w", slot, userID, err)
	}
	return nil
}

func (r *CardRepo) GetDecks(ctx context.Context, userID int64) ([]model.Deck, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, user_id, slot_index, deck_name, cards, created_at, updated_at
		FROM decks WHERE user_id=$1 ORDER BY slot_index`, userID)
	if err != nil {
		return nil, fmt.Errorf("get decks %d: %w", userID, err)
	}
	defer rows.Close()

	var decks []model.Deck
	for rows.Next() {
		var d model.Deck
		if err := rows.Scan(&d.ID, &d.UserID, &d.SlotIndex, &d.DeckName, &d.Cards, &d.CreatedAt, &d.UpdatedAt); err != nil {
			return nil, err
		}
		decks = append(decks, d)
	}
	return decks, rows.Err()
}

func (r *CardRepo) DeleteDeck(ctx context.Context, userID int64, slot int) error {
	if _, err := r.pool.Exec(ctx, `DELETE FROM decks WHERE user_id=$1 AND slot_index=$2`, userID, slot); err != nil {
		return fmt.Errorf("delete deck slot %d for user %d: %w", slot, userID, err)
	}
	return nil
}

// --- Bulk sync (クライアントからの一括同期) ---

func (r *CardRepo) SyncCards(ctx context.Context, tx pgx.Tx, userID int64, cards []model.UserCard) error {
	if _, err := tx.Exec(ctx, `DELETE FROM user_cards WHERE user_id=$1`, userID); err != nil {
		return fmt.Errorf("sync cards delete %d: %w", userID, err)
	}
	for _, c := range cards {
		if _, err := tx.Exec(ctx, `
			INSERT INTO user_cards (user_id, card_id, count, card_level, obtained)
			VALUES ($1, $2, $3, $4, $5)`,
			userID, c.CardID, c.Count, c.Level, c.Obtained); err != nil {
			return fmt.Errorf("sync cards insert %d card %d: %w", userID, c.CardID, err)
		}
	}
	return nil
}

func (r *CardRepo) SyncDecks(ctx context.Context, tx pgx.Tx, userID int64, decks []model.Deck) error {
	if _, err := tx.Exec(ctx, `DELETE FROM decks WHERE user_id=$1`, userID); err != nil {
		return fmt.Errorf("sync decks delete %d: %w", userID, err)
	}
	for _, d := range decks {
		if _, err := tx.Exec(ctx, `
			INSERT INTO decks (user_id, slot_index, deck_name, cards, updated_at)
			VALUES ($1, $2, $3, $4, NOW())`,
			userID, d.SlotIndex, d.DeckName, d.Cards); err != nil {
			return fmt.Errorf("sync decks insert %d slot %d: %w", userID, d.SlotIndex, err)
		}
	}
	return nil
}

func (r *CardRepo) GetDeckCards(ctx context.Context, userID int64, slotIndex int) ([]int, error) {
	var cardsJSON json.RawMessage
	err := r.pool.QueryRow(ctx, `SELECT cards FROM decks WHERE user_id=$1 AND slot_index=$2`, userID, slotIndex).Scan(&cardsJSON)
	if err != nil {
		return nil, fmt.Errorf("get deck cards user %d slot %d: %w", userID, slotIndex, err)
	}
	var cardIDs []int
	if err := json.Unmarshal(cardsJSON, &cardIDs); err != nil {
		return nil, fmt.Errorf("parse deck cards: %w", err)
	}
	return cardIDs, nil
}
