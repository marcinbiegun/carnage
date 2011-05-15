require 'rubygems'
require 'gosu'
require 'chipmunk'

# Nazwa programu
TITLE = 'Carnage 0.1'

# Rozmiar ekranu
SCREEN_WIDTH = 800
SCREEN_HEIGHT = 600

# Kroki do przerobienia dla chipmunka, dla każdego kroku Gosu (fizyka działa lepiej)
SUBSTEPS = 6

# Konwersja radianów na wektory (dwa wymiary)
class Numeric
  def radians_to_vec2
    CP::Vec2.new(Math::cos(self), Math::sin(self))
  end
end

# Kolejność pionowa obiektów
module ZOrder
  Background, Stars, Player, UI = *0..3
end

# Player, czyli samochód
class Player
  # .shape widoczny z zewnątrz obiektu
  attr_reader :shape

  # konfiguracja obiektu samochodu
  def initialize(window, shape)
    @image = Gosu::Image.new(window, "media/truck.bmp", false)
    @shape = shape
    @shape.body.p = CP::Vec2.new(0.0, 0.0) # Początkowa pozycja
    @shape.body.v = CP::Vec2.new(0.0, 0.0) # Początkowa prędkość

    @shape.body.a = (3*Math::PI/2.0) # Początkowy kierunek (góra)
  end

  # Ustawienie kierunku
  def warp(vect)
    @shape.body.p = vect
  end

  # Skręt (zmiana momentu obrotowego)
  def turn_left
    @shape.body.t -= 400.0/SUBSTEPS
  end

  # Skręt (zmiana momentu obrotowego)
  def turn_right
    @shape.body.t += 400.0/SUBSTEPS
  end

  # Przyśpieszenie - działamy odpowiednią siłą
  def accelerate
    @shape.body.apply_force((@shape.body.a.radians_to_vec2 * (3000.0/SUBSTEPS)), CP::Vec2.new(0.0, 0.0))
  end

  # Mocniejsze przyśpieszenie
  def boost
    @shape.body.apply_force((@shape.body.a.radians_to_vec2 * (3000.0)), CP::Vec2.new(0.0, 0.0))
  end

  # Hamowanie
  def reverse
    @shape.body.apply_force(-(@shape.body.a.radians_to_vec2 * (1000.0/SUBSTEPS)), CP::Vec2.new(0.0, 0.0))
  end

  # Sprawdzenie, czy pozycja jest ok (czy samochód nie opuścił ekranu)
  def validate_position
    l_position = CP::Vec2.new(@shape.body.p.x % SCREEN_WIDTH, @shape.body.p.y % SCREEN_HEIGHT)
    @shape.body.p = l_position
  end

  # Funkcja rysująca (wywoływana co krok)
  def draw
    @image.draw_rot(@shape.body.p.x, @shape.body.p.y, ZOrder::Player, @shape.body.a.radians_to_gosu)
  end
end

# Gwiazdka (przykładowy obiekt)
class Star

  # Shape widoczny z zewnątrz obiektu
  attr_reader :shape

  # Konfiguracja obiektu gwiazdki
  def initialize(animation, shape)
    @animation = animation
    @color = Gosu::Color.new(0xff000000)
    @color.red = 255
    @color.green = 255
    @color.blue = 255
    @shape = shape
    @shape.body.p = CP::Vec2.new(rand * SCREEN_WIDTH, rand * SCREEN_HEIGHT) # position
    @shape.body.v = CP::Vec2.new(0.0, 0.0) # velocity
    @shape.body.a = (3*Math::PI/2.0) # angle in radians; faces towards top of screen
    @shape.body.m = 10
  end

  # Funkcja rysująca (wywoływana co krok)
  def draw
    img = @animation[Gosu::milliseconds / 100 % @animation.size];
    img.draw(@shape.body.p.x - img.width / 2.0, @shape.body.p.y - img.height / 2.0, ZOrder::Stars, 1, 1, @color)
  end
end

# Główna klasa gry
class GameWindow < Gosu::Window
  def initialize
    super(SCREEN_WIDTH, SCREEN_HEIGHT, false, 16)
    self.caption = TITLE
    @background_image = Gosu::Image.new(self, "media/green.png", true)


    # Przykładowy dźwięk
    @beep = Gosu::Sample.new(self, "media/Beep.wav")

    # Punkty, napisy
    @score = 0
    @font = Gosu::Font.new(self, Gosu::default_font_name, 20)

    # Czas upływający do krok
    @dt = (1.0/60.0)

    # Tworzymy przestrzeń dla obiektów
    @space = CP::Space.new
    @space.damping = 0.2

    # Gracz (pojazd)
    body = CP::Body.new(10.0, 150.0)

    # Definiujemy kształt
    shape_array = [CP::Vec2.new(-25.0, -25.0), CP::Vec2.new(-25.0, 25.0), CP::Vec2.new(25.0, 1.0), CP::Vec2.new(25.0, -1.0)]
    shape = CP::Shape::Poly.new(body, shape_array, CP::Vec2.new(0,0))

    # Definiujemy typ dla kolizji
    shape.collision_type = :ship

    # Dodajemy do przestrzeni gracza i kształt
    @space.add_body(body)
    @space.add_shape(shape)

    # Ustawiamy graczowi kształt
    @player = Player.new(self, shape)
    @player.warp(CP::Vec2.new(320, 240)) # move to the center of the window

    # Ładujemy animację gwiazdek
    @star_anim = Gosu::Image::load_tiles(self, "media/tyre.png", 25, 25, false)

    # Gwazdki
    @stars = Array.new

    # Definicja kolizji (gwiazdka i pojazd)
    @remove_shapes = []
    @space.add_collision_func(:ship, :star) do |ship_shape, star_shape|
      @score += 10
      @beep.play
#      @remove_shapes << star_shape
    end

    # Definicja kolizji pustej dla dwóch gwiazdek
    @space.add_collision_func(:star, :star, &nil)
  end

  # Krok Gosu
  def update

    # Podkroki dla Chipmunka
    SUBSTEPS.times do

      # Usuwamy obiekty dodane do @remove_shapes
      @remove_shapes.each do |shape|
        @stars.delete_if { |star| star.shape == shape }
        @space.remove_body(shape.body)
        @space.remove_shape(shape)
      end
      @remove_shapes.clear # clear out the shapes for next pass

      # Resetujemy siły dizałające na ciało (by nie powtarzały się w pod-krokach)
      @player.shape.body.reset_forces

      # Sprawdzamy pozycję
      @player.validate_position

      # Reakcje na naciśnięte klawisze
      if button_down? Gosu::KbLeft
        @player.turn_left
      end
      if button_down? Gosu::KbRight
        @player.turn_right
      end
      if button_down? Gosu::KbUp
        if ( (button_down? Gosu::KbRightShift) || (button_down? Gosu::KbLeftShift) )
          @player.boost
        else
          @player.accelerate
        end
      elsif button_down? Gosu::KbDown
        @player.reverse
      end

      # Mija podany czas
      @space.step(@dt)
    end

    # Co krok dodajemy gwiazdkę
    if rand(100) < 4 and @stars.size < 25 then
      body = CP::Body.new(0.0001, 0.0001)
      shape = CP::Shape::Circle.new(body, 25/2, CP::Vec2.new(0.0, 0.0))
      shape.collision_type = :star

      @space.add_body(body)
      @space.add_shape(shape)

      @stars.push(Star.new(@star_anim, shape))
    end
  end

  # Rysowanie co krok
  def draw
    @background_image.draw(0, 0, ZOrder::Background)
    @player.draw
    @stars.each { |star| star.draw }
    @font.draw("Score: #{@score}", 10, 10, ZOrder::UI, 1.0, 1.0, 0xffffff00)
  end

  # Wyjście z gry klawisze escape
  def button_down(id)
    if id == Gosu::KbEscape
      close
    end
  end
end

window = GameWindow.new
window.show    
    

