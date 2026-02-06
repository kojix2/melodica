require "uing"
require "raudio"

WIN_W = 800
WIN_H = 600

KEYBOARD_HEIGHT = WIN_H / 3.0
VISUAL_HEIGHT   = WIN_H - KEYBOARD_HEIGHT

WHITE_KEY_COUNT = 15
WHITE_KEY_WIDTH = WIN_W.to_f / WHITE_KEY_COUNT
BLACK_KEY_WIDTH = WHITE_KEY_WIDTH * 0.6
BLACK_KEY_HEIGHT = KEYBOARD_HEIGHT * 0.6

ASSETS_DIR = File.expand_path("../assets", __DIR__)

INFO_FONT = UIng::FontDescriptor.new(
  family: "Arial",
  size: 12,
  weight: :normal,
  italic: :normal,
  stretch: :normal
)

# Each note: {key_name, white_key_index, is_black, sfx_id, hue}
# White keys: C4, D4, E4, F4, G4, A4, B4, C5, D5, E5, F5, G5, A5, B5, C6
# Black keys: C#4, D#4, F#4, G#4, A#4, C#5, D#5, F#5, G#5, A#5
NOTE_DATA = {
  # White keys (lower row keyboard: A S D F G H J K L ; ' \ and more)
  'a' => {index: 0, black: false, sfx: "c4", hue: 0.0},        # C4
  's' => {index: 1, black: false, sfx: "d4", hue: 0.08},       # D4
  'd' => {index: 2, black: false, sfx: "e4", hue: 0.16},       # E4
  'f' => {index: 3, black: false, sfx: "f4", hue: 0.24},       # F4
  'g' => {index: 4, black: false, sfx: "g4", hue: 0.32},       # G4
  'h' => {index: 5, black: false, sfx: "a4", hue: 0.40},       # A4
  'j' => {index: 6, black: false, sfx: "b4", hue: 0.48},       # B4
  'k' => {index: 7, black: false, sfx: "c5", hue: 0.56},       # C5
  'l' => {index: 8, black: false, sfx: "d5", hue: 0.64},       # D5 (placeholder, may not have sound)
  ';' => {index: 9, black: false, sfx: "e5", hue: 0.72},       # E5
  # Black keys (upper row keyboard: W E T Y U I O P)
  'w' => {index: 0, black: true, sfx: "cs4", hue: 0.04},       # C#4
  'e' => {index: 1, black: true, sfx: "ds4", hue: 0.12},       # D#4
  't' => {index: 3, black: true, sfx: "fs4", hue: 0.28},       # F#4
  'y' => {index: 4, black: true, sfx: "gs4", hue: 0.36},       # G#4
  'u' => {index: 5, black: true, sfx: "as4", hue: 0.44},       # A#4
  'o' => {index: 7, black: true, sfx: "cs5", hue: 0.60},       # C#5 (placeholder)
  'p' => {index: 8, black: true, sfx: "ds5", hue: 0.68},       # D#5 (placeholder)
}

# Black key positions relative to white keys (before which white key?)
BLACK_KEY_POSITIONS = [1, 2, 4, 5, 6, 8, 9, 11, 12, 13] # positions after C, D, F, G, A pattern repeated

def has_black_key_after?(white_index : Int32) : Bool
  # Piano pattern: C has black, D has black, E doesn't, F has black, G has black, A has black, B doesn't
  # Pattern repeats every 7 white keys
  case white_index % 7
  when 0, 1, 3, 4, 5 then true  # After C, D, F, G, A
  else                    false # After E, B
  end
end

class Particle
  property x : Float64
  property y : Float64
  property radius : Float64
  property max_radius : Float64
  property hue : Float64
  property alpha : Float64
  property created_at : Float64
  property lifetime : Float64

  def initialize(@x, @y, @hue, @created_at)
    @radius = 5.0
    @max_radius = 80.0 + rand * 60.0
    @alpha = 0.9
    @lifetime = 1.5 + rand * 1.0
  end

  def update(now : Float64) : Bool
    elapsed = now - @created_at
    return false if elapsed > @lifetime

    progress = elapsed / @lifetime
    @radius = 5.0 + (@max_radius - 5.0) * progress
    @alpha = (1.0 - progress) * 0.85
    true
  end
end

class VisualState
  getter particles : Array(Particle)
  getter pressed_keys : Set(Char)
  @start_time : Time::Instant

  def initialize
    @particles = [] of Particle
    @pressed_keys = Set(Char).new
    @start_time = Time.instant
  end

  def time_now : Float64
    (Time.instant - @start_time).total_seconds
  end

  def spawn_particle(key : Char, note_info)
    now = time_now
    # Position based on key index
    if note_info[:black]
      x = (note_info[:index] + 1) * WHITE_KEY_WIDTH - BLACK_KEY_WIDTH / 2.0 + rand * 20.0 - 10.0
    else
      x = (note_info[:index] + 0.5) * WHITE_KEY_WIDTH + rand * 20.0 - 10.0
    end
    y = VISUAL_HEIGHT * 0.3 + rand * VISUAL_HEIGHT * 0.5
    @particles << Particle.new(x, y, note_info[:hue], now)

    # Add some extra particles for sparkle effect
    2.times do
      px = x + rand * 60.0 - 30.0
      py = y + rand * 60.0 - 30.0
      p = Particle.new(px, py, note_info[:hue], now)
      p.max_radius = 30.0 + rand * 30.0
      p.lifetime = 0.8 + rand * 0.6
      @particles << p
    end
  end

  def update
    now = time_now
    @particles.reject! { |p| !p.update(now) }
  end

  def key_down(key : Char)
    @pressed_keys.add(key.downcase)
  end

  def key_up(key : Char)
    @pressed_keys.delete(key.downcase)
  end

  def key_pressed?(key : Char) : Bool
    @pressed_keys.includes?(key.downcase)
  end
end

class KeySfx
  @sounds : Hash(String, Raudio::Sound)

  def initialize
    @sounds = {} of String => Raudio::Sound
    load_sounds
  end

  private def load_sounds
    sound_files = {
      "c4"  => "key_c4.wav",
      "cs4" => "key_cs4.wav",
      "d4"  => "key_d4.wav",
      "ds4" => "key_ds4.wav",
      "e4"  => "key_e4.wav",
      "f4"  => "key_f4.wav",
      "fs4" => "key_fs4.wav",
      "g4"  => "key_g4.wav",
      "gs4" => "key_gs4.wav",
      "a4"  => "key_a4.wav",
      "as4" => "key_as4.wav",
      "b4"  => "key_b4.wav",
      "c5"  => "key_c5.wav",
      # Placeholder for notes without files - use closest available
      "cs5" => "key_c5.wav",
      "d5"  => "key_c5.wav",
      "ds5" => "key_c5.wav",
      "e5"  => "key_c5.wav",
    }

    sound_files.each do |id, file|
      path = File.join(ASSETS_DIR, file)
      if File.exists?(path)
        @sounds[id] = Raudio::Sound.load(path)
        @sounds[id].volume = 0.7_f32
      end
    end
  end

  def play(id : String)
    @sounds[id]?.try(&.play)
  end

  def release
    @sounds.each_value(&.release)
  end
end

def hue_to_rgb(h : Float64, s : Float64, l : Float64) : {Float64, Float64, Float64}
  c = (1.0 - (2.0 * l - 1.0).abs) * s
  x = c * (1.0 - ((h * 6.0) % 2.0 - 1.0).abs)
  m = l - c / 2.0

  r1, g1, b1 = case (h * 6.0).to_i
               when 0 then {c, x, 0.0}
               when 1 then {x, c, 0.0}
               when 2 then {0.0, c, x}
               when 3 then {0.0, x, c}
               when 4 then {x, 0.0, c}
               else        {c, 0.0, x}
               end

  {r1 + m, g1 + m, b1 + m}
end

def draw_text(ctx, text : String, x : Float64, y : Float64, width : Float64, align,
              font : UIng::FontDescriptor, r : Float64, g : Float64, b : Float64, a : Float64)
  UIng::Area::AttributedString.open(text) do |attr|
    color = UIng::Area::Attribute.new_color(r, g, b, a)
    attr.set_attribute(color, 0, attr.len)
    UIng::Area::Draw::TextLayout.open(
      string: attr,
      default_font: font,
      width: width,
      align: align
    ) do |text_layout|
      ctx.draw_text_layout(text_layout, x, y)
    end
  end
end

def run_melodica
  UIng.init
  Raudio::AudioDevice.init

  sfx = KeySfx.new
  visual = VisualState.new

  window = UIng::Window.new("Melodica", WIN_W, WIN_H, menubar: false)
  box = UIng::Box.new(:vertical, padded: false)

  handler = UIng::Area::Handler.new do
    draw do |_area, params|
      ctx = params.context

      # Draw dark background for visual area
      bg = UIng::Area::Draw::Brush.new(:solid, 0.02, 0.02, 0.05, 1.0)
      ctx.fill_path(bg, &.add_rectangle(0, 0, WIN_W, VISUAL_HEIGHT))

      # Draw particles (glowing orbs)
      visual.particles.each do |p|
        r, g, b = hue_to_rgb(p.hue, 0.8, 0.5)

        # Outer glow
        glow_brush = UIng::Area::Draw::Brush.new(:solid, r, g, b, p.alpha * 0.3)
        ctx.fill_path(glow_brush) do |path|
          path.new_figure_with_arc(p.x, p.y, p.radius * 1.5, 0.0, Math::PI * 2.0, false)
        end

        # Inner bright core
        core_brush = UIng::Area::Draw::Brush.new(:solid, r, g, b, p.alpha * 0.8)
        ctx.fill_path(core_brush) do |path|
          path.new_figure_with_arc(p.x, p.y, p.radius * 0.6, 0.0, Math::PI * 2.0, false)
        end

        # Center highlight
        highlight_brush = UIng::Area::Draw::Brush.new(:solid, 1.0, 1.0, 1.0, p.alpha * 0.4)
        ctx.fill_path(highlight_brush) do |path|
          path.new_figure_with_arc(p.x, p.y, p.radius * 0.2, 0.0, Math::PI * 2.0, false)
        end
      end

      # Separator line
      sep_brush = UIng::Area::Draw::Brush.new(:solid, 0.3, 0.3, 0.35, 1.0)
      ctx.fill_path(sep_brush, &.add_rectangle(0, VISUAL_HEIGHT, WIN_W, 2))

      # Draw keyboard
      keyboard_y = VISUAL_HEIGHT + 2

      # Draw white keys first
      WHITE_KEY_COUNT.times do |i|
        x = i * WHITE_KEY_WIDTH

        # Check if this key is pressed
        pressed = NOTE_DATA.any? do |char, info|
          !info[:black] && info[:index] == i && visual.key_pressed?(char)
        end

        if pressed
          key_brush = UIng::Area::Draw::Brush.new(:solid, 0.85, 0.85, 0.75, 1.0)
        else
          key_brush = UIng::Area::Draw::Brush.new(:solid, 0.98, 0.98, 0.96, 1.0)
        end
        ctx.fill_path(key_brush, &.add_rectangle(x + 1, keyboard_y, WHITE_KEY_WIDTH - 2, KEYBOARD_HEIGHT - 4))

        border_brush = UIng::Area::Draw::Brush.new(:solid, 0.4, 0.4, 0.42, 1.0)
        ctx.stroke_path(border_brush, thickness: 1.0) do |path|
          path.add_rectangle(x + 1, keyboard_y, WHITE_KEY_WIDTH - 2, KEYBOARD_HEIGHT - 4)
        end
      end

      # Draw black keys on top
      WHITE_KEY_COUNT.times do |i|
        next unless has_black_key_after?(i)
        next if i >= WHITE_KEY_COUNT - 1

        x = (i + 1) * WHITE_KEY_WIDTH - BLACK_KEY_WIDTH / 2.0

        # Check if this black key is pressed
        pressed = NOTE_DATA.any? do |char, info|
          info[:black] && info[:index] == i && visual.key_pressed?(char)
        end

        if pressed
          black_brush = UIng::Area::Draw::Brush.new(:solid, 0.25, 0.25, 0.28, 1.0)
        else
          black_brush = UIng::Area::Draw::Brush.new(:solid, 0.1, 0.1, 0.12, 1.0)
        end
        ctx.fill_path(black_brush, &.add_rectangle(x, keyboard_y, BLACK_KEY_WIDTH, BLACK_KEY_HEIGHT))

        # Add slight highlight on black keys
        highlight = UIng::Area::Draw::Brush.new(:solid, 0.2, 0.2, 0.22, 1.0)
        ctx.fill_path(highlight, &.add_rectangle(x + 2, keyboard_y + 2, BLACK_KEY_WIDTH - 4, 4))
      end

      # Draw key labels
      draw_text(
        ctx,
        "Keys: A S D F G H J K L ; (white) | W E T Y U O P (black) | ESC to quit",
        10.0,
        VISUAL_HEIGHT - 25.0,
        WIN_W.to_f - 20.0,
        UIng::Area::Draw::TextAlign::Center,
        INFO_FONT,
        0.6,
        0.6,
        0.65,
        0.9
      )
    end

    key_event do |area, event|
      key = event.key.downcase

      if event.up != 0
        # Key released
        visual.key_up(key)
        area.queue_redraw_all
        next true
      end

      # Key pressed
      if event.ext_key == UIng::Area::ExtKey::Escape
        UIng.quit
        next true
      end

      if NOTE_DATA.has_key?(key)
        # Only trigger sound on initial press (not repeat)
        unless visual.key_pressed?(key)
          note_info = NOTE_DATA[key]
          sfx.play(note_info[:sfx])
          visual.spawn_particle(key, note_info)
        end
        visual.key_down(key)
      end

      area.queue_redraw_all
      true
    end
  end

  area = UIng::Area.new(handler, WIN_W, WIN_H)
  box.append(area, stretchy: true)
  window.child = box

  UIng.timer(16) do
    visual.update
    area.queue_redraw_all
    1
  end

  window.on_closing do
    sfx.release
    Raudio::AudioDevice.close
    UIng.quit
    true
  end

  window.show
  UIng.main
  UIng.uninit
end

{% if flag?(:preview_mt) && flag?(:execution_context) %}
  {% if flag?(:darwin) %}
    run_melodica
  {% else %}
    gui_context = Fiber::ExecutionContext::Isolated.new("ui") do
      run_melodica
    end
    gui_context.wait
  {% end %}
{% else %}
  run_melodica
{% end %}
