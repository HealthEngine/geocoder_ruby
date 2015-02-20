class Geocoder
  def self.missing(start_id, end_id, bing_key)

    Geocoder.configure(:lookup => :bing, :api_key => bing_key)
    @db = ActiveRecord::Base.connection



    p "Searching between id #{start_id} and id #{end_id}"
    
    
    @address_strings_plus_id = []



    # select all the addresses that need geocoding
    addr_query = "SELECT * FROM provider_addresses WHERE (latitude is null or longitude is null) AND id >= #{start_id} AND id <= #{end_id}"

    rows = @db.select_all(addr_query)
    # return if there are no addresses to geocode
    next if rows.count < 1

    total_to_count = rows.count
    p "#{total_to_count} addresses to geocode"
    
    rows.each do |row|
      street_string = row['doximity_address']
      address_modifiers = [" St", " Ave", " Ct", " Pl", " Dr", " Rd", " Street", "Road", " Way", " Pkwy"]
      address_modifiers.each do |modifier|
        if street_string.include?(modifier)
          street_string = street_string.partition(modifier).first + modifier
          p "#street string: #{street_string}"
        end
      end
      city_state_zip = ", #{row['doximity_city']}, #{row['doximity_state']}, #{row['doximity_zip']}"
      id = row['id']
      @address_strings_plus_id << [street_string + city_state_zip, id]
    end
    success_count = 0
    fail_count = 0 
    @address_strings_plus_id.each do |address, id|
      coordinates = Geocoder.coordinates(address)
      unless coordinates.nil?
        lat = coordinates[0]
        lon = coordinates[1]

        # update address record
        @db.execute "UPDATE provider_addresses SET latitude=#{lat}, longitude=#{lon} WHERE id=#{id}"
        success_count += 1
      else
        first_number_string = address[/\d+/]
        last_hope = "#{first_number_string.to_i}#{address.partition(first_number_string).last}"
        p "last hope address: #{last_hope}"
        coordinates = Geocoder.coordinates(last_hope)
        unless coordinates.nil?
          lat = coordinates[0]
          lon = coordinates[1]
          p "last hope successful, id:#{id}"
          @db.execute "UPDATE provider_addresses SET latitude=#{lat}, longitude=#{lon} WHERE id=#{id}"
          success_count += 1
        else
         p "Unable to get coordinates for #{id}"
         fail_count += 1
       end
     end
     if success_count != 0 && fail_count != 0
      p "success: #{success_count}"
      p "fail_count #{fail_count}"
      p "Success percentage #{(success_count.to_f/(fail_count.to_f+success_count.to_f)).round(2)*100}%"
    end
  end
  p "finished"
end