package masterdata

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"sync"
)

type Card struct {
	ID           int             `json:"id"`
	Name         string          `json:"name"`
	Rarity       string          `json:"rarity"`
	Type         string          `json:"type"`
	Element      string          `json:"element,omitempty"`
	Cost         CardCost        `json:"cost"`
	AP           int             `json:"ap"`
	HP           int             `json:"hp"`
	SpellType    string          `json:"spell_type,omitempty"`
	ItemType     string          `json:"item_type,omitempty"`
	Effect       string          `json:"effect,omitempty"`
	AbilityParsed json.RawMessage `json:"ability_parsed,omitempty"`
	EffectParsed  json.RawMessage `json:"effect_parsed,omitempty"`
}

type CardCost struct {
	EP            int      `json:"ep"`
	LandsRequired []string `json:"lands_required,omitempty"`
}

type StatBonus struct {
	AP int `json:"ap"`
	HP int `json:"hp"`
}

var (
	cards   map[int]*Card
	cardsMu sync.RWMutex
)

func LoadCards(dataDir string) error {
	cardsMu.Lock()
	defer cardsMu.Unlock()

	cards = make(map[int]*Card)

	files := []string{
		"fire_1.json", "fire_2.json",
		"water_1.json", "water_2.json",
		"earth_1.json", "earth_2.json",
		"wind_1.json", "wind_2.json",
		"neutral_1.json", "neutral_2.json",
		"spell_1.json", "spell_2.json",
		"item.json",
	}

	for _, f := range files {
		path := filepath.Join(dataDir, f)
		if err := loadCardFile(path); err != nil {
			slog.Warn("skipping card file", "file", f, "err", err)
		}
	}

	slog.Info("card master data loaded", "total", len(cards))
	return nil
}

func loadCardFile(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read %s: %w", path, err)
	}

	var file struct {
		Cards []Card `json:"cards"`
	}
	if err := json.Unmarshal(data, &file); err != nil {
		return fmt.Errorf("parse %s: %w", path, err)
	}

	for i := range file.Cards {
		c := &file.Cards[i]
		cards[c.ID] = c
	}
	return nil
}

func GetCard(id int) *Card {
	cardsMu.RLock()
	defer cardsMu.RUnlock()
	return cards[id]
}

func GetAllCards() map[int]*Card {
	cardsMu.RLock()
	defer cardsMu.RUnlock()
	result := make(map[int]*Card, len(cards))
	for k, v := range cards {
		result[k] = v
	}
	return result
}

func IsCreature(id int) bool {
	c := GetCard(id)
	return c != nil && c.Type == "creature"
}

func IsSpell(id int) bool {
	c := GetCard(id)
	return c != nil && c.Type == "spell"
}

func IsItem(id int) bool {
	c := GetCard(id)
	return c != nil && c.Type == "item"
}

func HasKeyword(id int, keyword string) bool {
	c := GetCard(id)
	if c == nil || c.AbilityParsed == nil {
		return false
	}
	var parsed struct {
		Keywords []string `json:"keywords"`
	}
	if err := json.Unmarshal(c.AbilityParsed, &parsed); err != nil {
		return false
	}
	for _, kw := range parsed.Keywords {
		if kw == keyword {
			return true
		}
	}
	return false
}

func GetItemStatBonus(id int) StatBonus {
	c := GetCard(id)
	if c == nil || c.EffectParsed == nil {
		return StatBonus{}
	}
	var parsed struct {
		StatBonus StatBonus `json:"stat_bonus"`
	}
	json.Unmarshal(c.EffectParsed, &parsed)
	return parsed.StatBonus
}
