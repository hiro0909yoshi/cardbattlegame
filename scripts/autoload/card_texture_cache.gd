# CardTextureCache - Singleton cache for rendered card textures
# Reduces draw calls by rendering each card once to a texture instead of instantiating 47-node Card.tscn for each hand card
class_name CardTextureCache
extends Node

## Cache mapping: card_id (int) -> ImageTexture
var _texture_cache: Dictionary[int, ImageTexture] = {}

## Reference to Card.tscn for rendering
var _card_scene = preload("res://scenes/Card.tscn")

## Card rendering dimensions (matches CardFrame.tscn)
const CARDFRAME_WIDTH = 220
const CARDFRAME_HEIGHT = 293

## Get a cached card texture, or create one asynchronously
## Returns the ImageTexture when ready, cached on subsequent calls
func get_card_texture(card_id: int) -> ImageTexture:
	# Return cached texture if available
	if card_id in _texture_cache:
		return _texture_cache[card_id]

	# Return null if not cached (caller must wait for async render)
	return null

## Get cached texture synchronously without rendering
## Returns null if not in cache - use this for non-async contexts
func get_card_texture_sync(card_id: int) -> ImageTexture:
	return _texture_cache.get(card_id, null)

## Render a single card and cache its texture
## This is async - the texture won't be available until rendering completes
func prerender_card_async(card_id: int) -> ImageTexture:
	# Return cached texture if already available
	if card_id in _texture_cache:
		return _texture_cache[card_id]

	# Create and return the texture asynchronously
	var texture = await _render_card_to_texture(card_id)
	_texture_cache[card_id] = texture
	return texture

## Render multiple cards asynchronously
## Use this to pre-load cards before they're displayed
func prerender_cards(card_ids: Array[int]) -> void:
	for card_id in card_ids:
		if card_id not in _texture_cache:
			var texture = await _render_card_to_texture(card_id)
			if texture:
				_texture_cache[card_id] = texture

## Remove a texture from cache (call if card data changes)
func invalidate(card_id: int) -> void:
	if card_id in _texture_cache:
		_texture_cache.erase(card_id)

## Clear entire cache
func clear_cache() -> void:
	_texture_cache.clear()

## Internal: Render a card to an ImageTexture
## Returns the ImageTexture after rendering completes
func _render_card_to_texture(card_id: int) -> ImageTexture:
	# Check cache first (in case another coroutine already rendered it)
	if card_id in _texture_cache:
		return _texture_cache[card_id]

	# Create SubViewport for rendering
	var viewport = SubViewport.new()
	viewport.size = Vector2i(CARDFRAME_WIDTH, CARDFRAME_HEIGHT)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.disable_3d = true
	add_child(viewport)

	# Instantiate Card.tscn
	var card_instance = _card_scene.instantiate()
	if not card_instance:
		push_error("[CardTextureCache] Failed to instantiate Card.tscn")
		viewport.queue_free()
		return null

	# Configure card for rendering
	card_instance.position = Vector2.ZERO
	card_instance.size = Vector2(CARDFRAME_WIDTH, CARDFRAME_HEIGHT)
	card_instance.custom_minimum_size = Vector2(CARDFRAME_WIDTH, CARDFRAME_HEIGHT)

	viewport.add_child(card_instance)

	# Load card data
	if card_instance.has_method("load_card_data"):
		card_instance.load_card_data(card_id)

	# Wait for rendering to complete (2 frames for viewport to render)
	await get_tree().process_frame
	await get_tree().process_frame

	# Capture viewport texture
	var viewport_texture = viewport.get_texture()
	if not viewport_texture:
		push_error("[CardTextureCache] Failed to get viewport texture for card_id %d" % card_id)
		viewport.queue_free()
		return null

	# Create ImageTexture from the viewport image
	var image = viewport_texture.get_image()
	if not image:
		push_error("[CardTextureCache] Failed to get image from viewport for card_id %d" % card_id)
		viewport.queue_free()
		return null

	var image_texture = ImageTexture.create_from_image(image)

	# Cleanup viewport
	viewport.queue_free()

	return image_texture

## Synchronous render (blocks until complete) - use sparingly
## Only use if you absolutely need the texture immediately
func render_card_sync(card_id: int) -> ImageTexture:
	if card_id in _texture_cache:
		return _texture_cache[card_id]

	# Create SubViewport for rendering
	var viewport = SubViewport.new()
	viewport.size = Vector2i(CARDFRAME_WIDTH, CARDFRAME_HEIGHT)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.disable_3d = true
	add_child(viewport)

	# Instantiate Card.tscn
	var card_instance = _card_scene.instantiate()
	if not card_instance:
		push_error("[CardTextureCache] Failed to instantiate Card.tscn")
		viewport.queue_free()
		return null

	# Configure card for rendering
	card_instance.position = Vector2.ZERO
	card_instance.size = Vector2(CARDFRAME_WIDTH, CARDFRAME_HEIGHT)
	card_instance.custom_minimum_size = Vector2(CARDFRAME_WIDTH, CARDFRAME_HEIGHT)

	viewport.add_child(card_instance)

	# Load card data
	if card_instance.has_method("load_card_data"):
		card_instance.load_card_data(card_id)

	# Force render (need to process frames for viewport to update)
	get_tree().root.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Process frames to let rendering happen
	for _i in range(3):
		await get_tree().process_frame

	# Capture viewport texture
	var viewport_texture = viewport.get_texture()
	if not viewport_texture:
		push_error("[CardTextureCache] Failed to get viewport texture for card_id %d" % card_id)
		viewport.queue_free()
		return null

	# Create ImageTexture from the viewport image
	var image = viewport_texture.get_image()
	if not image:
		push_error("[CardTextureCache] Failed to get image from viewport for card_id %d" % card_id)
		viewport.queue_free()
		return null

	var image_texture = ImageTexture.create_from_image(image)

	# Cleanup viewport
	viewport.queue_free()

	return image_texture
