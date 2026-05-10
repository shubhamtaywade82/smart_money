module SmartMoney
  class CandleSeries
    include Enumerable

    attr_reader :capacity, :size

    def initialize(capacity: SmartMoney.configuration.default_series_capacity)
      raise ArgumentError, "capacity must be positive" unless capacity.positive?

      @capacity = capacity
      @buffer   = Array.new(capacity)
      @head     = 0
      @size     = 0
    end

    def append(candle)
      @buffer[@head] = candle
      @head          = (@head + 1) % @capacity
      @size          = [@size + 1, @capacity].min
      self
    end

    alias << append

    def [](index)
      if index >= 0
        return nil if index >= @size
      else
        return nil if index.abs > @size
      end
      @buffer[internal_index(index)]
    end

    def last(n = 1)
      n = [n, @size].min
      Array.new(n) { |i| self[-(n - i)] }
    end

    def first
      self[-@size]
    end

    def highest_high(n = @size)
      n = [n, @size].min
      last(n).max_by(&:high).high
    end

    def lowest_low(n = @size)
      n = [n, @size].min
      last(n).min_by(&:low).low
    end

    def full?
      @size == @capacity
    end

    def empty?
      @size.zero?
    end

    def each
      @size.times { |i| yield self[-@size + i] }
    end

    def to_a
      last(@size)
    end

    private

    def internal_index(index)
      if index >= 0
        (@head - @size + index) % @capacity
      else
        (@head + index) % @capacity
      end
    end
  end
end
