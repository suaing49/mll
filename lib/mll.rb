module MLL

  def self.nest_list f, expr, n
    Enumerator.new do |e|
      e << expr
      n.times do
        e << expr = f.call(expr)
      end
    end
  end
  # def self.nest *args
  #   nest_list(*args).last
  # end
  def self.nest f, expr, n
    n.times{ expr = f.call expr }
    expr
  end

  def self.fold_list f, x, list = nil
    # TODO teach it to accept Range ?
    x, *list = x unless list
    # TODO use Ruby#inject ?
    Enumerator.new do |e|
      e << x
      list.each do |i|
        e << x = f.call(x, i)
      end
    end
  end

  def self.table f, *args
    [].tap do |result|
      [[result, args.map{ |r| # add lazy?
        r.respond_to?(:map) && r.first.respond_to?(:map) ?
          r.first : range(*r)
      }]].tap do |stack|
        stack.each do |ai, ri|
          # TODO try to make #table lazy (Enumerator instead of Array)
          # "no implicit conversion of Enumerator::Lazy into Array"
          # "undefined method `replace' for #<Enumerator::Lazy: []>"
          ai.replace ri.first.map{ |i|
            if ri.size == 1
              f.call(*ai, i)
            else
              [*ai.dup, i].tap{ |t| stack << [t, ri.drop(1)] }
            end
          }
        end
      end
    end
  end

  # http://reference.wolfram.com/language/ref/Listable.html
  def self.define_listable_function name, &block
    (class << self; self end).class_eval do # http://stackoverflow.com/a/12792313/322020
      define_method name do |*args|
        case args.map{ |i| i.respond_to? :map }
          when [true] ; args.first.lazy.map &method(name)
          when [true, true] ; args.first.lazy.zip(args.last).map{ |i, j| send name, i, j }
          when [true, false] ; args.first.lazy.map{ |i| send name, i, args.last }
          when [false, true] ; args.last.lazy.map{ |i| send name, args.first, i }
        else
          block.call *args
        end
      end
    end
  end

  define_listable_function :range do |*args|
    case args.size
    when 1 ; range 1, args[0] # TODO do smth with #table(-n)
    when 2 ; Range.new(args[0], args[1]).step
    when 3
      case args[2] <=> 0
      when 0 ; raise ArgumentError.new("step can't be zero")
      when 1 ; Range.new(args[0], args[1]).step args[2]
      else
        Enumerator.new do |e|
          from, to, step = *args
          # while (step > 0) ? from <= to : from >= to
          while from >= to
            e << from
            from += step
          end
        end
      end
    else
      raise ArgumentError.new("wrong number of arguments (#{args.size} for 1..3)")
    end
  end

  define_listable_function (:subtract) { |a, b| a - b }
  define_listable_function (:divide) { |a, b| a / b }
  define_listable_function (:_plus) { |a, b| a + b }
  define_listable_function (:_times) { |a, b| a * b }

  # http://reference.wolfram.com/language/ref/Orderless.html
  def self.define_orderless_function name, &block
    (class << self; self end).class_eval do # http://stackoverflow.com/a/12792313/322020
      define_method name do |*args|
        args.inject do |memo, obj|
          block.call memo, obj
        end
      end
    end
  end

  define_orderless_function (:plus) { |a, b| _plus a, b }
  define_orderless_function (:times) { |a, b| _times a, b }

  def self.subdivide *args
    case args.size
      when 1 ; subdivide 1, args[0]
      when 2 ; subdivide 0, args[0], args[1]
      when 3 ; range(args[0], args[1], (args[1] - args[0]) * 1.0 / args[2])
      ## using only pure Ruby methods makes unittests more reliable
      # when 3 ; plus args[0], divide(times(1.0, args[1] - args[0], range(0, args[2])), args[2])
    else
      raise ArgumentError.new("wrong number of arguments (#{args.size} for 1..3)")
    end
  end

end
