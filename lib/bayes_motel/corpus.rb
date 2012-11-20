module BayesMotel
  class Corpus
    INFTY = 1.0 / 0.0


    def initialize(persistence)
      @persistence = persistence
    end

    def train(doc, category, id=0)
      id == 0 ? id = @persistence.total_count : old_category = @persistence.document_category(id)
      if old_category
        if old_category.to_s != category.to_s
          @persistence.edit_document(id, category)
          _training(doc, old_category, "negative")
          _training(doc, category)
        end
      else
        @persistence.increment_total()
        @persistence.create_document(id, category)
        _training(doc, category)
      end
    end

    def score(doc)
      _score(doc).symbolize_keys
    end

    def destroy_document(doc, id, category=nil )
      unless category
        category = @persistence.document_category(id)
      end
      @persistence.destroy_document(id)
      _training(doc, category, "negative")
    end
    def destroy_classifier
      @persistence.destroy_classifier
    end

    def cleanup
      @persistence.cleanup
    end

    def total_count
      @persistence.total_count
    end

    def classify(doc)
      results = score(doc)
      max = [:none, 0]
      results.each_pair do |(k, v)|
        max = [k, v] if v > max[1]
      end
      max
    end

    private

    def _probabilities(document, variable_name, probs = {})

      @persistence.raw_counts(variable_name).each do |category, keys|
        cat = probs[category] ||= {}
        probs[category] = probability(category, keys, variable_name, document)
      end
      return probs
    end

    def probability(category, keys, variable_name, document)

      doc_prob = doc_probability(category, keys, variable_name, document)
      cat_prob = category_probability(category)

      doc_prob * cat_prob
    end

    def doc_probability(category, keys, variable_name, document)
      doc_prob = 1
      TextHash.new(document).each do |word, count|

        word_prob = word_probability(category, keys, variable_name, word, count)

        doc_prob *= word_prob
      end
      return doc_prob
    end

    def word_probability(category, keys, variable_name, word, count)
      word_count = @persistence.word_count(variable_name, category)
      #count how many total words we've seen for this category (eg ham) and variable (eg title)

      appearances = (keys[word.to_s] || 0).to_f

      prob = count.to_f * ((appearances + 1).to_f / word_count.to_f)

      prob
    end

    def category_probability(category)
      @persistence.document_count(category) / @persistence.total_count.to_f
    end

    def _score(variables, name='', probs={})
      variables.each_pair do |k, v|
        case v
        when Hash
          _score(v, "#{name}_#{k}", probs)
        else
          _probabilities(v, "#{name}_#{k}", probs)
        end
      end

      probs.keys.each { |k|
        k1 = probs[k]
        k2 = Math.exp(probs[k])
        probs[k] = (probs[k] == -INFTY) ? 0 : k1
      }

      # normalize to get probs
      sum = probs.values.inject { |x,y|
        x+y
      }
      probs.keys.each { |k|
        probs[k] = sum.zero? ? 0 : probs[k] / sum
      }
      probs
    end

    def _training(variables, category, polarity="positive" , name='')
      variables.each_pair do |k, v|
        case v
        when Hash
          _training(v, category, polarity, "#{name}_#{k}")
        else
          @persistence.save_training(category, "#{name}_#{k}", v, polarity)
        end
      end
    end
  end
end
