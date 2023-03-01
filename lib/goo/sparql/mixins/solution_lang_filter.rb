module Goo
  module SPARQL
    module Solution
      class  LanguageFilter

        def initialize
          @other_languages_values = {}
        end

        attr_reader :other_languages_values

        def main_lang_filter(id, attr, value)
          index, value = lang_index value
          save_other_lang_val(id, attr, index, value) unless index.nil? ||index.eql?(:no_lang)
          [index, value]
        end

        def find_model_objects_by_lang(objects_by_lang, lang, model_id, predicate)
          objects_by_lang[lang]&.find { |obj| obj[:id].eql?(model_id) && obj[:predicate].eql?(predicate) }
        end

        def fill_models_with_other_languages(models_by_id, objects_by_lang, list_attributes, attributes,klass)
      
          other_platform_languages = [:EN, :FR]

          unless other_platform_languages.empty?
            
            models_by_id&.each do |id, model|
              
              attributes&.each do |attr|
                
                other_platform_languages.each do |lang|
                  
                  model_attribute_val = model.instance_variable_get("@#{attr}")
                  model_objects_by_lang = find_model_objects_by_lang(objects_by_lang, lang, id, attr) || []

                  next if model_objects_by_lang.empty?

                  if list_attributes.include?(attr)
                    model_attribute_val ||= []
                    if model_attribute_val.empty?
                      model.send("#{attr}=", model_attribute_val + model_objects_by_lang[:objects], on_load: true)
                    end
                  elsif !model_attribute_val
                    model.send("#{attr}=", model_objects_by_lang[:objects][0] , on_load: true)
                  end
                  
                end
              end
            end
          end
        end

        def languages_values_to_set(language_values, no_lang_values)

          values = nil
          matched_lang, not_matched_lang = matched_languages(language_values, no_lang_values)
          if !matched_lang.empty?
            main_lang = Array(matched_lang[:'0']) + Array(matched_lang[:no_lang])
            if main_lang.empty?
              secondary_languages = matched_lang.select { |key| key != :'0' && key != :no_lang }.sort.map { |x| x[1] }
              values = secondary_languages.first
            else
              values = main_lang
            end
          elsif !not_matched_lang.empty?
            values = not_matched_lang
          end
          values&.uniq
        end

        private

        def lang_index(object)
          return [nil, object] unless  object.is_a?(RDF::Literal)

          lang = object.language

          if lang.nil?
            [:no_lang, object]
          else
            index = Goo.language_includes(lang)
            index = index ? index.to_s.to_sym : :not_matched
            [index, object]
          end
        end

        def save_other_lang_val(id, attr, index, value)
          @other_languages_values[id] ||= {}
          @other_languages_values[id][attr] ||= {}
          @other_languages_values[id][attr][index] ||= []
          
          unless @other_languages_values[id][attr][index].include?(value.to_s)
            @other_languages_values[id][attr][index] += Array(value.to_s)
          end
        end

        def matched_languages(index_values, model_attribute_val)
          not_matched_lang = index_values[:not_matched]
          matched_lang = index_values.reject { |key| key == :not_matched }
          unless model_attribute_val.nil? || Array(model_attribute_val).empty?
            matched_lang[:no_lang] = Array(model_attribute_val)
          end
          [matched_lang, not_matched_lang]
        end
      end
    end
  end
end
