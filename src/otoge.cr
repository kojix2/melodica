require "uing"
require "raudio"
require "json"

WIN_W = 800
WIN_H = 600

LANE_COUNT      =     4
LANE_WIDTH      = 120.0
LANE_GAP        =  12.0
LANE_AREA_WIDTH = LANE_COUNT * LANE_WIDTH + (LANE_COUNT - 1) * LANE_GAP
LANE_LEFT       = (WIN_W - LANE_AREA_WIDTH) / 2.0

HIT_LINE_Y   = WIN_H - 120.0
NOTE_WIDTH   = LANE_WIDTH - 16.0
NOTE_HEIGHT  =  18.0
SCROLL_SPEED = 360.0

PERFECT_WINDOW = 0.06
GOOD_WINDOW    = 0.12
MISS_WINDOW    = 0.18

LANE_KEYS           = ['D', 'F', 'J', 'K']
DEFAULT_SFX_BY_LANE = ["c4", "e4", "g4", "c5"]
MENU_KEYS_MAX       = 26

ASSETS_DIR = File.expand_path("../assets", __DIR__)

HUD_FONT = UIng::FontDescriptor.new(
  family: "Arial",
  size: 14,
  weight: :normal,
  italic: :normal,
  stretch: :normal
)

JUDGE_FONT = UIng::FontDescriptor.new(
  family: "Arial",
  size: 28,
  weight: :bold,
  italic: :normal,
  stretch: :normal
)

SELECT_FONT = UIng::FontDescriptor.new(
  family: "Arial",
  size: 18,
  weight: :bold,
  italic: :normal,
  stretch: :normal
)

class Note
  getter lane : Int32
  getter time : Float64
  getter sfx_id : String
  property? judged : Bool
  property? hit : Bool

  def initialize(@lane : Int32, @time : Float64, @sfx_id : String)
    @judged = false
    @hit = false
  end
end

class GameState
  getter notes : Array(Note)
  getter score : Int32
  getter combo : Int32
  getter max_combo : Int32
  getter perfects : Int32
  getter goods : Int32
  getter misses : Int32
  getter last_judgement : String
  getter last_judgement_at : Float64
  getter? started : Bool

  @start_time : Time::Instant = Time.instant
  @last_note_time : Float64

  def initialize(@notes : Array(Note))
    @last_note_time = @notes.max_of(&.time)
    @score = 0
    @combo = 0
    @max_combo = 0
    @perfects = 0
    @goods = 0
    @misses = 0
    @last_judgement = "-"
    @last_judgement_at = -1.0
    reset_stats
    @started = false
  end

  def reset!
    @notes.each do |note|
      note.judged = false
      note.hit = false
    end
    reset_stats
    @started = false
    @start_time = Time.instant
  end

  def start(music : Raudio::Music)
    return if @started
    @started = true
    @start_time = Time.instant
    music.play
  end

  def time_now : Float64
    return 0.0 unless @started
    (Time.instant - @start_time).total_seconds
  end

  def finished?(now : Float64, music : Raudio::Music) : Bool
    return false unless @started
    now > (@last_note_time + MISS_WINDOW) && !music.playing?
  end

  def update(now : Float64)
    return unless @started
    @notes.each do |note|
      next if note.judged?
      if now - note.time > MISS_WINDOW
        register_miss(now)
        note.judged = true
      end
    end
  end

  def hit_lane(lane : Int32, now : Float64) : String?
    return unless @started
    candidate = nil
    best_diff = Float64::INFINITY

    @notes.each do |note|
      next if note.judged? || note.lane != lane
      diff = (now - note.time).abs
      if diff < best_diff
        best_diff = diff
        candidate = note
      end
    end

    return unless candidate
    if best_diff <= PERFECT_WINDOW
      register_hit(candidate, 100, "Perfect", now)
      return candidate.sfx_id
    elsif best_diff <= GOOD_WINDOW
      register_hit(candidate, 50, "Good", now)
      return candidate.sfx_id
    elsif best_diff <= MISS_WINDOW
      register_miss(now)
      candidate.judged = true
      return candidate.sfx_id
    end
    nil
  end

  private def register_hit(note : Note, points : Int32, label : String, now : Float64)
    note.judged = true
    note.hit = true
    @score += points
    @combo += 1
    @max_combo = {@max_combo, @combo}.max
    if label == "Perfect"
      @perfects += 1
    else
      @goods += 1
    end
    @last_judgement = label
    @last_judgement_at = now
  end

  private def register_miss(now : Float64)
    @misses += 1
    @combo = 0
    @last_judgement = "Miss"
    @last_judgement_at = now
  end

  private def reset_stats
    @score = 0
    @combo = 0
    @max_combo = 0
    @perfects = 0
    @goods = 0
    @misses = 0
    @last_judgement = "-"
    @last_judgement_at = -1.0
  end

  def judgement_popup_alpha(now : Float64) : Float64
    return 0.0 if @last_judgement_at < 0.0
    elapsed = now - @last_judgement_at
    return 0.0 if elapsed > 0.6
    (1.0 - elapsed / 0.6).clamp(0.0, 1.0)
  end
end

class KeySfx
  def initialize
    @sounds = {
      "c4"  => Raudio::Sound.load(File.join(ASSETS_DIR, "key_c4.wav")),
      "cs4" => Raudio::Sound.load(File.join(ASSETS_DIR, "key_cs4.wav")),
      "db4" => Raudio::Sound.load(File.join(ASSETS_DIR, "key_db4.wav")),
      "d4"  => Raudio::Sound.load(File.join(ASSETS_DIR, "key_d4.wav")),
      "ds4" => Raudio::Sound.load(File.join(ASSETS_DIR, "key_ds4.wav")),
      "eb4" => Raudio::Sound.load(File.join(ASSETS_DIR, "key_eb4.wav")),
      "e4"  => Raudio::Sound.load(File.join(ASSETS_DIR, "key_e4.wav")),
      "f4"  => Raudio::Sound.load(File.join(ASSETS_DIR, "key_f4.wav")),
      "fs4" => Raudio::Sound.load(File.join(ASSETS_DIR, "key_fs4.wav")),
      "gb4" => Raudio::Sound.load(File.join(ASSETS_DIR, "key_gb4.wav")),
      "g4"  => Raudio::Sound.load(File.join(ASSETS_DIR, "key_g4.wav")),
      "gs4" => Raudio::Sound.load(File.join(ASSETS_DIR, "key_gs4.wav")),
      "ab4" => Raudio::Sound.load(File.join(ASSETS_DIR, "key_ab4.wav")),
      "a4"  => Raudio::Sound.load(File.join(ASSETS_DIR, "key_a4.wav")),
      "as4" => Raudio::Sound.load(File.join(ASSETS_DIR, "key_as4.wav")),
      "bb4" => Raudio::Sound.load(File.join(ASSETS_DIR, "key_bb4.wav")),
      "b4"  => Raudio::Sound.load(File.join(ASSETS_DIR, "key_b4.wav")),
      "c5"  => Raudio::Sound.load(File.join(ASSETS_DIR, "key_c5.wav")),
    }
    @sounds.each_value(&.volume=(0.7_f32))
  end

  def play_id(id : String)
    @sounds[id]?.try(&.play)
  end

  def release
    @sounds.each_value(&.release)
  end
end

struct Song
  getter title : String
  getter audio : String
  getter chart : String

  def initialize(@title : String, @audio : String, @chart : String)
  end
end

def build_chart : Array(Note)
  notes = [] of Note
  lead_in = 1.0
  bpm = 120.0
  beat_interval = 60.0 / bpm
  beats = 16
  lane_seq = [0, 1, 2, 3]

  beats.times do |i|
    lane = lane_seq[i % lane_seq.size]
    notes << Note.new(lane, lead_in + i * beat_interval, DEFAULT_SFX_BY_LANE[lane])
  end

  notes
end

def load_songs(path : String) : Array(Song)
  data = JSON.parse(File.read(path))
  data["songs"].as_a.map do |entry|
    Song.new(
      entry["title"].as_s,
      entry["audio"].as_s,
      entry["chart"].as_s
    )
  end
rescue
  [] of Song
end

def load_chart(path : String) : Array(Note)
  data = JSON.parse(File.read(path))
  data["notes"].as_a.map do |entry|
    lane = entry["lane"].as_i
    sfx = entry["sfx"]?.try(&.as_s) || DEFAULT_SFX_BY_LANE[lane]
    Note.new(lane, entry["t"].as_f, sfx)
  end
rescue
  build_chart
end

def hud_text(state : GameState) : String
  "Score: #{state.score}\nCombo: #{state.combo}\nMax: #{state.max_combo}\n" +
    "Perfect: #{state.perfects}\nGood: #{state.goods}\nMiss: #{state.misses}"
end

def status_text(state : GameState, now : Float64, music : Raudio::Music) : String
  if !state.started?
    "Press Space to start. Keys: D F J K"
  elsif state.finished?(now, music)
    "Done! Press Space to restart."
  else
    "Playing... Keys: D F J K"
  end
end

def selection_text(songs : Array(Song), selected_index : Int32) : String
  lines = ["Select Song (Up/Down, Enter)", ""]
  songs.each_with_index do |song, index|
    marker = index == selected_index ? ">" : " "
    if index < MENU_KEYS_MAX
      key = ('A'.ord + index).chr
      lines << "#{marker} [#{key}] #{song.title}"
    else
      lines << "#{marker} #{song.title}"
    end
  end
  lines.join("\n")
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

def run_game
  UIng.init
  Raudio::AudioDevice.init

  songs = load_songs(File.join(ASSETS_DIR, "songs.json"))
  if songs.empty?
    songs = [Song.new("Warmup 120", "sample.wav", "charts/warmup.json")]
  end
  selected_index = 0
  selection_mode = true

  music : Raudio::Music? = nil
  state : GameState? = nil
  sfx = KeySfx.new

  start_song = ->(song : Song) do
    music.try do |current|
      current.stop
      current.release
    end

    chart_path = File.join(ASSETS_DIR, song.chart)
    notes = load_chart(chart_path)
    new_state = GameState.new(notes)

    music_path = File.join(ASSETS_DIR, song.audio)
    loaded_music = Raudio::Music.load(music_path)
    loaded_music.looping = false
    loaded_music.volume = 0.8
    music = loaded_music
    state = new_state
    new_state.start(loaded_music)
    selection_mode = false
  end

  {% if flag?(:preview_mt) && flag?(:execution_context) %}
    audio_stop = Channel(Nil).new
    audio_context = Fiber::ExecutionContext::Parallel.new("audio", 1)
    audio_context.spawn(name: "audio") do
      loop do
        break if audio_stop.closed?
        music.try { |current| current.update if current.playing? }
        sleep 10.milliseconds
      end
    end
  {% end %}

  window = UIng::Window.new("Otoge (Minimal)", WIN_W, WIN_H, menubar: false)
  box = UIng::Box.new(:vertical, padded: true)

  handler = UIng::Area::Handler.new do
    draw do |_area, params|
      ctx = params.context
      bg = UIng::Area::Draw::Brush.new(:solid, 0.06, 0.08, 0.10, 1.0)
      ctx.fill_path(bg, &.add_rectangle(0, 0, WIN_W, WIN_H))

      if selection_mode
        draw_text(
          ctx,
          selection_text(songs, selected_index),
          80.0,
          120.0,
          WIN_W.to_f - 160.0,
          UIng::Area::Draw::TextAlign::Left,
          SELECT_FONT,
          0.92,
          0.92,
          0.92,
          0.98
        )
        next
      end

      game_state = state
      current_music = music
      unless game_state && current_music
        next
      end

      lane_brush = UIng::Area::Draw::Brush.new(:solid, 0.14, 0.16, 0.20, 1.0)
      edge_brush = UIng::Area::Draw::Brush.new(:solid, 0.30, 0.32, 0.36, 1.0)

      LANE_COUNT.times do |lane|
        x = LANE_LEFT + lane * (LANE_WIDTH + LANE_GAP)
        ctx.fill_path(lane_brush, &.add_rectangle(x, 0, LANE_WIDTH, WIN_H))
        ctx.stroke_path(edge_brush, thickness: 1.0) do |path|
          path.add_rectangle(x, 0, LANE_WIDTH, WIN_H)
        end
      end

      hit_brush = UIng::Area::Draw::Brush.new(:solid, 0.90, 0.76, 0.26, 1.0)
      ctx.stroke_path(hit_brush, thickness: 3.0) do |path|
        path.new_figure(LANE_LEFT, HIT_LINE_Y)
        path.line_to(LANE_LEFT + LANE_AREA_WIDTH, HIT_LINE_Y)
      end

      now = game_state.time_now
      note_brush = UIng::Area::Draw::Brush.new(:solid, 0.24, 0.68, 0.88, 1.0)
      ghost_brush = UIng::Area::Draw::Brush.new(:solid, 0.16, 0.30, 0.38, 0.6)

      game_state.notes.each do |note|
        next if note.judged?
        y = HIT_LINE_Y - (note.time - now) * SCROLL_SPEED
        next if y < -NOTE_HEIGHT || y > WIN_H + NOTE_HEIGHT

        x = LANE_LEFT + note.lane * (LANE_WIDTH + LANE_GAP)
        x += (LANE_WIDTH - NOTE_WIDTH) / 2.0
        brush = note.time < now ? ghost_brush : note_brush
        ctx.fill_path(brush, &.add_rectangle(x, y - NOTE_HEIGHT / 2.0, NOTE_WIDTH, NOTE_HEIGHT))
      end

      draw_text(
        ctx,
        hud_text(game_state),
        16.0,
        14.0,
        220.0,
        UIng::Area::Draw::TextAlign::Left,
        HUD_FONT,
        0.92,
        0.92,
        0.92,
        0.95
      )

      draw_text(
        ctx,
        status_text(game_state, now, current_music),
        0.0,
        WIN_H - 36.0,
        WIN_W.to_f,
        UIng::Area::Draw::TextAlign::Center,
        HUD_FONT,
        0.92,
        0.92,
        0.92,
        0.95
      )

      popup_alpha = game_state.judgement_popup_alpha(now)
      if popup_alpha > 0.0 && game_state.last_judgement != "-"
        draw_text(
          ctx,
          game_state.last_judgement,
          0.0,
          HIT_LINE_Y - 140.0,
          WIN_W.to_f,
          UIng::Area::Draw::TextAlign::Center,
          JUDGE_FONT,
          1.0,
          0.9,
          0.3,
          popup_alpha
        )
      end
    end

    key_event do |area, event|
      next true if event.up != 0
      if selection_mode
        case event.ext_key
        when UIng::Area::ExtKey::Up
          selected_index = (selected_index - 1 + songs.size) % songs.size
        when UIng::Area::ExtKey::Down
          selected_index = (selected_index + 1) % songs.size
        end

        key = event.key
        if key >= 'a' && key <= 'z'
          key = (key.ord - 32).chr
        end
        if key >= 'A' && key <= 'Z'
          index = key.ord - 'A'.ord
          if index < songs.size
            selected_index = index
            start_song.call(songs[selected_index])
          end
        elsif key == '\r' || key == '\n' || key == ' '
          start_song.call(songs[selected_index])
        end
        area.queue_redraw_all
        next true
      end

      game_state = state
      current_music = music
      unless game_state && current_music
        area.queue_redraw_all
        next true
      end
      case event.key
      when 'd', 'D'
        id = game_state.hit_lane(0, game_state.time_now) || DEFAULT_SFX_BY_LANE[0]
        sfx.play_id(id)
      when 'f', 'F'
        id = game_state.hit_lane(1, game_state.time_now) || DEFAULT_SFX_BY_LANE[1]
        sfx.play_id(id)
      when 'j', 'J'
        id = game_state.hit_lane(2, game_state.time_now) || DEFAULT_SFX_BY_LANE[2]
        sfx.play_id(id)
      when 'k', 'K'
        id = game_state.hit_lane(3, game_state.time_now) || DEFAULT_SFX_BY_LANE[3]
        sfx.play_id(id)
      when ' '
        if !game_state.started?
          game_state.start(current_music)
        elsif game_state.finished?(game_state.time_now, current_music)
          current_music.stop
          current_music.seek(0.0_f32)
          game_state.reset!
          game_state.start(current_music)
        end
      end
      if event.ext_key == UIng::Area::ExtKey::Escape
        current_music.stop
        current_music.release
        music = nil
        state = nil
        selection_mode = true
      end
      area.queue_redraw_all
      true
    end
  end

  area = UIng::Area.new(handler, WIN_W, WIN_H)

  box.append(area, stretchy: true)
  window.child = box

  UIng.timer(16) do
    if (game_state = state) && game_state.started?
      {% unless flag?(:preview_mt) && flag?(:execution_context) %}
        music.try(&.update)
      {% end %}
      game_state.update(game_state.time_now)
    end

    area.queue_redraw_all
    1
  end

  window.on_closing do
    {% if flag?(:preview_mt) && flag?(:execution_context) %}
      audio_stop.close
    {% end %}
    music.try do |current|
      current.stop
      current.release
    end
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
  gui_context = Fiber::ExecutionContext::Isolated.new("ui") do
    run_game
  end
  gui_context.wait
{% else %}
  run_game
{% end %}
