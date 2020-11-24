module SpecHelper
  class TestClock < Skylight::Util::Clock
    alias __tick tick

    def initialize # rubocop:disable Lint/MissingSuper
      @absolute_secs = nil
      @tick = nil
      @skew = 0
    end

    def absolute_secs
      (@absolute_secs || __absolute_secs) + @skew / 1_000_000_000
    end

    def tick
      (@tick || __tick) + @skew
    end

    def skip(val)
      @skew += (val * 1_000_000_000).to_i
    end

    def freeze
      @absolute_secs = __absolute_secs
      @tick = __tick
    end

    def unfreeze
      @absolute_secs = nil
      @tick = nil
    end

    attr_writer :tick

    private

      def __absolute_secs
        Time.now.to_i
      end
  end

  def mock_clock!
    return if Skylight::Util::Clock.default.is_a?(TestClock)

    Skylight::Util::Clock.default = TestClock.new
  end

  def reset_clock!
    Skylight::Util::Clock.default = Skylight::Util::Clock.new
  end

  module_function

  def clock
    c = Skylight::Util::Clock.default
    c.is_a?(TestClock) ? c : nil
  end
end
