module Goo
  module SPARQL
    module Solution
      class  LanguageFilter
        
        attr_reader :requested_lang, :unmapped, :objects_by_lang

        def initialize(requested_lang: nil, unmapped: false, list_attributes: [])
          @attributes_to_translate = [:synonym, :prefLabel, :definition]
          @list_attributes = list_attributes
          @objects_by_lang = {}
          @unmapped = unmapped
          @requested_lang = requested_lang
        end

        def enrich_models(models_by_id)
          
          ## if the requested language is ALL, we can enrich the models with the objects by language
          objects_by_lang.each do |id, predicates|
            model = models_by_id[id]
            predicates.each do |predicate, values|
              if @attributes_to_translate.any? { |attr| predicate.eql?(attr) }
                save_model_values(model, values, predicate, unmapped) 
              end
            end
          end  
        end
        

        def set_model_value(model, predicate, objects, object)
                    
          language = object_language(object)

          if requested_lang.eql?(:ALL) || !literal?(object) || language_match?(language)
            model.send("#{predicate}=", objects, on_load: true)
          end 

          if requested_lang.eql?(:ALL) || requested_lang.is_a?(Array)
            language = "@none" if language.nil? || language.eql?(:no_lang)
            store_objects_by_lang(model.id, predicate, object, language)
          end

        end

        def model_set_unmapped(model, predicate, value)
          language = object_language(value)
          if requested_lang.eql?(:ALL) || language.nil? || language_match?(language)
            return add_unmapped_to_model(model, predicate, value)
          end
          
          store_objects_by_lang(model.id, predicate, value, language)
        end

        def model_group_by_lang(model, requested_lang)
          unmapped = model.unmapped 
          cpy = {}
  
          unmapped.each do |attr, v|          
             cpy[attr] = is_a_uri?(v.first) ? v.to_a : v.group_by { |x| x.language.to_s }
          end
  
          model.unmapped = cpy
        end


        private

        def is_a_uri?(value)
          value.is_a?(RDF::URI) && value.valid?
        end

        def object_language(new_value)
          new_value.language || :no_lang if new_value.is_a?(RDF::Literal)
        end

        def language_match?(language)
          # no_lang means that the object is not a literal
          if language.eql?(:no_lang)
            return true 
          end

          if requested_lang.is_a?(Array)
            return requested_lang.include?(language)
          end

          return language.eql?(requested_lang)

        end

        def store_objects_by_lang(id, predicate, object, language)
          # store objects in this format: [id][predicate][language] = [objects]

          return if requested_lang.is_a?(Array) && !requested_lang.include?(language)

          language_key = language.downcase  
            
          objects_by_lang[id] ||= {}
          objects_by_lang[id][predicate] ||= {}
          objects_by_lang[id][predicate][language_key] ||= []

          objects_by_lang[id][predicate][language_key] << object
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
            
            if !list_attributes?(predicate)
              values = values.map { |k, v| [k, v.first] }.to_h
            end

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


        def literal?(object)
          return object_language(object).nil? ? false : true
        end

      end
    end
  end
end
