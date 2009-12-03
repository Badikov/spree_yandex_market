module Export
  class YandexMarket
    include ActionController::UrlWriter
    attr_accessor :host, :currencies
    
    SCHEME = Nokogiri::XML('<!DOCTYPE yml_catalog SYSTEM "shops.dtd" />')
    DEFAULT_OFFEN = "vendor_model"

    def helper
      @helper ||= ApplicationController.helpers
    end
  
    def export
      @config = ::YandexMarket.first
      @host = @config.preferred_url
      ActionController::Base.asset_host = @config.preferred_url
      
      @currencies = @config.preferred_currency.split(';').map{|x| x.split(':')}
      @currencies.first[1] = 1
      
      @categories = Taxon.find_by_name(@config.preferred_category)
      @categories = @categories.self_and_descendants
      @categories_ids = @categories.collect { |x| x.id }
            
      Nokogiri::XML::Builder.new({ :encoding =>"windows-1251"}, SCHEME) do |xml|
        xml.yml_catalog(:date => Time.now.to_s(:ym)) {
          
          xml.shop { # описание магазина
            xml.name    @config.preferred_short_name
            xml.company @config.preferred_full_name
            xml.url     @config.preferred_url
          }
          
          xml.currencies { # описание используемых валют в магазине
            @currencies && @currencies.each do |curr|
              opt = {:id => curr.first, :rate => curr[1] }
              opt.merge!({ :plus => curr[2]}) if curr[2] && ["CBRF","NBU","NBK","CB"].include?(curr[1])
              xml.currency(opt)
            end
          }        
        
          xml.categories { # категории товара
            @categories_ids && @categories.each do |cat|
              @cat_opt = { :id => cat.id }
              @cat_opt.merge!({ :parentId => cat.parent_id}) unless cat.parent_id.blank?
              xml.category(@cat_opt){ xml  << cat.name }
            end
          }
          xml.offers { # список товаров
            @categories && @categories.each do |cat|
              products = @config.preferred_wares == "on_hand" ? cat.products.active.on_hand : cat.products.active      
              products && products.each do |product|
                offer(xml,product, cat)
              end
            end          
          }
        } 
      end.to_xml
    
    end
    
    
    private
  # :type => "book"
  # :type => "audiobook"
  # :type => misic
  # :type => video
  # :type => tour
  # :type => event_ticket
    
    def path_to_url(path)
      "http://#{@host.sub(%r[^http://],'')}/#{path.sub(%r[^/],'')}"
    end
  
    def offer(xml,product, cat)
      
      product_properties = { }
      product.product_properties.map {|x| product_properties[x.property_name] = x.value }
      wares_type_value = product_properties[@config.preferred_wares_type]
      if ["book", "audiobook", "music", "video", "tour", "event_ticket"].include? wares_type_value
        send("offer_#{wares_type_value}".to_sym, xml, product, cat)
      else
        send("offer_#{DEFAULT_OFFEN}".to_sym, xml, product, cat)      
      end
    end
    
    # общая часть для всех видов продукции
    def shared_xml(xml, product, cat)
      xml.url product_url(product, :host => @host)
      xml.price product.price
      xml.currencyId @currencies.first.first
      xml.categoryId cat.id
      xml.picture path_to_url(product.images.first.attachment.url(:small, false)) unless product.images.empty?
    end

    
  # Обычное описание
    def offer_vendor_model(xml,product, cat)
      product_properties = { }
      product.product_properties.map {|x| product_properties[x.property_name] = x.value }
      opt = { :id => product.id, :type => "vendor.model", :available => product.has_stock? }
      xml.offer(opt) {
        shared_xml(xml, product, cat)
        xml.delivery               !product.shipping_category.blank?
        xml.local_delivery_cost    @config.preferred_local_delivery_cost if @config.preferred_local_delivery_cost
        xml.typePrefix product_properties[@config.preferred_type_prefix] if product_properties[@config.preferred_type_prefix]
        xml.vendor product_properties[@config.preferred_vendor] if product_properties[@config.preferred_vendor]    
        xml.vendorCode product_properties[@config.preferred_vendor_code] if product_properties[@config.preferred_vendor_code]
        xml.model                  product_properties[@config.preferred_model] if product_properties[@config.preferred_model]
        xml.description            product.description if product.description
        xml.manufacturer_warranty  !product_properties[@config.preferred_manufacturer_warranty].blank? 
        xml.country_of_origin      product_properties[@config.preferred_country_of_manufacturer] if product_properties[@config.preferred_country_of_manufacturer]
        xml.downloadable false
      }
    end

    # простое описание
    def offer_simple(xml, product, cat)
      product_properties = { }
      product.product_properties.map {|x| product_properties[x.property_name] = x.value }
      opt = { :id => product.id,  :available => product.has_stock? }
      xml.offer(opt) {
        shared_xml(xml, product, cat)
        xml.delivery            !product.shipping_category.blank?        
        xml.local_delivery_cost @config.preferred_local_delivery_cost 
        xml.name                product.name
        xml.vendorCode          product_properties[@config.preferred_vendor_code]
        xml.description         product.description
        xml.country_of_origin   product_properties[@config.preferred_country_of_manufacturer]
        xml.downloadable false   
      }
  end
    
    # Книги
    def offer_book(xml, product, cat)
      product_properties = { }
      product.product_properties.map {|x| product_properties[x.property_name] = x.value }
      opt = { :id => product.id, :type => "book", :available => product.has_stock? }
      xml.offer(opt) {
        shared_xml(xml, product, cat)
        
        xml.delivery !product.shipping_category.blank?        
        xml.local_delivery_cost @config.preferred_local_delivery_cost
        
        xml.author ""
        xml.name product.name
        xml.publisher ""
        xml.series ""
        xml.year ""
        xml.ISBN ""
        xml.volume ""
        xml.part ""
        xml.language ""
      
        xml.binding ""
        xml.page_extent ""
        
        xml.description product.description
        xml.downloadable false
      }
  end
    
    # Аудиокниги
    def offer_audiobook(xml, product, cat)
      product_properties = { }
      product.product_properties.map {|x| product_properties[x.property_name] = x.value }      
      opt = { :id => product.id, :type => "audiobook", :available => product.has_stock?  }
      xml.offer(opt) {  
        shared_xml(xml, product, cat)
        
        xml.author ""
        xml.name product.name
        xml.publisher ""
        xml.series ""
        xml.year ""
        xml.ISBN ""
        xml.volume ""
        xml.part ""
        xml.language ""
      
        xml.performed_by ""
        xml.storage ""
        xml.format ""
        xml.recording_length ""
        xml.description product.description
        xml.downloadable true
      
      }
    end
    
  # Описание музыкальной продукции
    def offer_music(xml, product, cat)
      product_properties = { }
      product.product_properties.map {|x| product_properties[x.property_name] = x.value }
      opt = { :id => product.id, :type => "artist.title", :available => product.has_stock?  }
      xml.offer(opt) {
        shared_xml(xml, product, cat)
        xml.delivery !product.shipping_category.blank?                

      
        xml.artist ""
        xml.title ""
        xml.year ""
        xml.media ""
        xml.volume ""
        
        xml.description product.description
        
    }
    end
    
    # Описание видео продукции:
    def offer_video(xml, product, cat)
      product_properties = { }
      product.product_properties.map {|x| product_properties[x.property_name] = x.value }
      opt = { :id => product.id, :type => "artist.title", :available => product.has_stock?  }
      xml.offer(opt) {
        shared_xml(xml, product, cat)
        
        xml.delivery !product.shipping_category.blank?                
        xml.title ""
        xml.year ""
        xml.media ""
        xml.starring ""
        xml.director ""
        xml.originalName ""
        xml.country_of_origin
        xml.description product_url.description
      }
  end
    
  # Описание тура
    def offer_tour(xml, product, cat)
      product_properties = { }
      product.product_properties.map {|x| product_properties[x.property_name] = x.value }
      opt = { :id => product.id, :type => "tour", :available => product.has_stock?  }
      xml.offer(opt) {
        shared_xml(xml, product, cat)
        
        xml.delivery !product.shipping_category.blank?                
        xml.local_delivery_cost @config.preferred_local_delivery_cost
        xml.worldRegion ""
        xml.country ""
        xml.region ""
        xml.days ""
        xml.dataTour ""
        xml.dataTour ""
        xml.name ""
        xml.hotel_stars ""
        xml.room ""
        xml.meal ""
        xml.included ""
        xml.transport ""
        xml.description product.description
      }
    end
    
    # Описание билетов на мероприятия
    def offer_event_ticket(xml, product, cat)
      product_properties = { }
      product.product_properties.map {|x| product_properties[x.property_name] = x.value }      
      opt = { :id => product.id, :type => "event-ticket", :available => product.has_stock?  }    
      xml.offer(opt) {
        shared_xml(xml, product, cat)
        
        xml.delivery !product.shipping_category.blank?                        
        xml.local_delivery_cost @config.preferred_local_delivery_cost
        
        xml.name product.name
        xml.place ""
        xml.hall(:plan => "url_plan") { xml << "" }
        xml.hall_part ""
        xml.date ""
        xml.is_premiere ""
        xml.is_kids ""
        xml.description product.description
      }
    end
    
  end
  
end
