module Goo
  module SPARQL
    module Solution
      class  LanguageFilter
        
        attr_reader :requested_lang, :unmapped, :objects_by_lang

        def initialize(requested_lang: nil, unmapped: false, list_attributes: [])
          @list_attributes = list_attributes
          @objects_by_lang = {}
          @unmapped = unmapped
          @requested_lang = requested_lang
          @fill_other_languages = init_requested_lang
          @requested_lang = @requested_lang.to_s.upcase.to_sym
        end

        def enrich_models(models_by_id)

          return unless fill_other_languages?

          other_platform_languages = Goo.main_languages[1..] || []

          objects_by_lang.each do |id, predicates|
            model = models_by_id[id]
            predicates.each do |predicate, languages|
              model_attribute_val = get_model_attribute_value(model, predicate)
              next unless model_attribute_val.nil? || model_attribute_val.empty?

              other_platform_languages.each do |platform_language|
                if languages[platform_language.to_s.upcase.to_sym]
                    save_model_values(model, languages[platform_language], predicate, unmapped)
                  break
                end
              end
              model_attribute_val = get_model_attribute_value(model, predicate)
              if model_attribute_val.nil? || model_attribute_val.empty?
                save_model_values(model, languages.values.flatten.uniq, predicate, unmapped)
              end
            end
          end
        
        end
        

        def set_model_value(model, predicate, objects)
          new_value = Array(objects).last
          language = object_language(new_value) # if lang is nil, it means that the object is not a literal
          if language.nil?
            return model.send("#{predicate}=", objects, on_load: true)
          elsif language_match?(language)
            return if language.eql?(:no_lang) && !model.instance_variable_get("@#{predicate}").nil? && !objects.is_a?(Array)

            return model.send("#{predicate}=", objects, on_load: true)
          end


          store_objects_by_lang(model.id, predicate, new_value, language)
        end

        def model_set_unmapped(model, predicate, value)
          language = object_language(value)
          if language.nil? || language_match?(language)
            return add_unmapped_to_model(model, predicate, value)
          end
          
          store_objects_by_lang(model.id, predicate, value, language)
        end


        private

        def object_language(new_value)
          new_value.language || :no_lang if new_value.is_a?(RDF::Literal)
        end

        def language_match?(language)
          !language.nil? && (language.eql?(requested_lang) || language.eql?(:no_lang) || requested_lang.nil?)
        end

        def store_objects_by_lang(id, predicate, object, language)
          # store objects in this format: [id][predicate][language] = [objects]

          objects_by_lang[id] ||= {}
          objects_by_lang[id][predicate] ||= {}
          objects_by_lang[id][predicate][language] ||= []

          objects_by_lang[id][predicate][language] << object
        end

        def init_requested_lang
          if @requested_lang.nil?
            @requested_lang = Goo.main_languages[0] || :EN
            return true
          end

          false
        end

        def get_model_attribute_value(model, predicate)
          if unmapped
            unmapped_get(model, predicate)
          else
            model.instance_variable_get("@#{predicate}")
          end
        end


        def add_unmapped_to_model(model, predicate, value)
          if model.respond_to? :klass # struct
            model[:unmapped] ||= {}
            model[:unmapped][predicate] ||= []
            model[:unmapped][predicate]  << value unless value.nil?
          else
            model.unmapped_set(predicate, value)
          end
        end

        def save_model_values(model, values, predicate, unmapped)
          if unmapped
            add_unmapped_to_model(model, predicate, values)
          else
            values = values.map(&:object)
            values = Array(values).min unless list_attributes?(predicate)
            model.send("#{predicate}=", values, on_load: true)
          end
        end

        def unmapped_get(model, predicate)
          if model && model.respond_to?(:klass) # struct
            model[:unmapped]&.dig(predicate)
          else
            model.unmapped_get(predicate)
          end

        end

        def list_attributes?(predicate)
          @list_attributes.include?(predicate)
        end


        def fill_other_languages?
          @fill_other_languages
        end

      end
    end
  end
end
