require "baby_face/configuration"
require 'pstore'

class BabyFace::Stand
  def initialize(mod)
    @mod = mod
    @categories = mod.class.class_variable_get(:@@_categories)
    @categories.each do |category|
      self.class.class_eval do
        define_method("#{category}?") {
          bayes.classify(to_feature).downcase == category.to_s
        }

        define_method("train_#{category}") {
          bayes.train(category, to_feature)
          save
        }
      end
    end
  end

  def to_feature
    def scan(prefix, obj)
      obj.class.class_variable_get(:@@_features).map do |attr|
        _prefix = prefix.nil? ? attr : "#{prefix}_#{attr}"
        value = obj.send(attr)
        case value
        when BabyFace
          scan(_prefix, value)
        when Array
          value.map do |val|
            scan(_prefix, val)
          end
        when Hash
          value.map do |key, val|
            scan("#{_prefix}_#{key}", val)
          end
        else
          wakachi(value.to_s).map do |text|
            "#{_prefix}_#{text}"
          end
        end
      end
    end
    scan(nil, @mod).flatten.join(" ")
  end

  def wakachi(text)
    text.split
  end

  def data_path
    Pathname.new(BabyFace::Configuration.data_dir).join(@mod.class.name.downcase)
  end

  def pstore
    @pstore ||= PStore.new(data_path)
  end

  def save
    pstore.transaction do
      pstore[@mod.class.name] = bayes
    end
  end

  private
  def bayes
    require 'classifier'
    @bayes ||= if data_path.exist?
                 pstore.transaction(true) do
                   pstore[@mod.class.name]
                 end
                else
                 ::Classifier::Bayes.new *@categories
                end
  end
end
