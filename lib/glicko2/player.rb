module Glicko2
  class Player
    TOLERANCE = 0.0000001

    attr_reader :mean, :sd, :volatility, :obj

    def self.from_obj(obj)
      mean = (obj.rating - GLICKO_INTERCEPT) / GLICKO_GRADIENT
      sd = obj.rating_deviation / GLICKO_GRADIENT
      new(mean, sd, obj.volatility, obj)
    end

    def initialize(mean, sd, volatility, obj)
      @mean = mean
      @sd = sd
      @volatility = volatility
      @obj = obj
      @e = {}
    end

    def g
      @g ||= 1 / Math.sqrt(1 + 3 * sd ** 2 / Math::PI ** 2)
    end

    def e(other)
      @e[other] ||= 1 / (1 + Math.exp(-other.g * (mean - other.mean)))
    end

    def variance(others)
      return 0.0 if others.length < 1
      others.reduce(0) do |v, other|
        e_other = e(other)
        v + other.g ** 2 * e_other * (1 - e_other)
      end ** -1
    end

    def delta(others, scores)
      others.zip(scores).reduce(0) do |d, (other, score)|
        d + other.g * (score - e(other))
      end * variance(others)
    end

    def f_part1(x, d, v)
      exp_x = Math.exp(x)
      sd_sq = sd ** 2
      (exp_x * (d ** 2 - sd_sq - v - exp_x)) / (2 * (sd_sq + v + exp_x) ** 2)
    end

    def f_part2(x)
      (x - Math::log(volatility ** 2)) / VOLATILITY_CHANGE ** 2
    end

    def f(x, d, v)
      f_part1(x, d, v) - f_part2(x)
    end

    def volatility1(d, v)
      a = Math::log(volatility ** 2)
      if d > sd ** 2 + v
        b = Math.log(d - sd ** 2 - v)
      else
        k = 1
        k += 1 while f(a - k * VOLATILITY_CHANGE, d, v) < 0
        b = a - k * VOLATILITY_CHANGE
      end
      fa = f(a, d, v)
      fb = f(b, d, v)
      while (b - a).abs > TOLERANCE
        c = a + (a - b) * fa / (fb - fa)
        fc = f(c, d, v)
        if fc * fb < 0
          a = b
          fa = fb
        else
          fa /= 2.0
        end
        b = c
        fb = fc
      end
      Math.exp(a / 2.0)
    end

    def generate_next(others, scores)
      if others.length < 1
        generate_next_without_games
      else
        generate_next_with_games(others, scores)
      end
    end

    def update_obj
      @obj.rating = GLICKO_GRADIENT * mean + GLICKO_INTERCEPT
      @obj.rating_deviation = GLICKO_GRADIENT * sd
      @obj.volatility = volatility
    end

    def to_s
      "#<Player mean=#{mean}, sd=#{sd}, volatility=#{volatility}, obj=#{obj}>"
    end

    private

    def generate_next_without_games
      sd_pre = Math.sqrt(sd ** 2 + volatility ** 2)
      self.class.new(mean, sd_pre, volatility, obj)
    end

    def generate_next_with_games(others, scores)
      _v = variance(others)
      _d = delta(others, scores)
      _volatility = volatility1(_d, _v)
      sd_pre = Math.sqrt(sd ** 2 + _volatility ** 2)
      _sd = 1 / Math.sqrt(1 / sd_pre ** 2 + 1 / _v)
      _mean = mean + _sd ** 2 * others.zip(scores).reduce(0) {
        |x, (other, score)| x + other.g * (score - e(other))
      }
      self.class.new(_mean, _sd, _volatility, obj)
    end
  end
end