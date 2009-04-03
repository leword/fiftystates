#!/usr/bin/ruby

require File.join(File.dirname(__FILE__), '..', 'rbutils', 'legislation')
module Hawaii  
  include Scrapable
  
  class Bill
    attr_reader :session
		def initialize(detail_url, year, chamber)
      @detail_url = detail_url
      @year = year
			@chamber = chamber
			@session = "#{@year} Session"
    end
    
		# Determine if bill is eligable for the year requested
		def eligable?
			@eligable ||= (not (detail_page.at('table/tr:nth(2)/td').inner_text =~ /[0-9]{1,2}\/[0-9]{1,2}\/#{@year}/).nil?)
		end
		
		def name
			detail_page.at('div.clearrow:nth(1) > div.rightside').inner_text
		end

    def bill_id
      detail_page.at('h3/a').inner_text
    end
    
    def primary_sponsor
      detail_page.at('div.clearrow:nth(6) > div.rightside').inner_text
    end

		def actions
			detail_page.search('table/tr').collect do |row|
				if row.at('td').nil?
					{}
				else
					@action_chamber = ""
					if row.at('td:nth(1)').inner_text == "H"
						@action_chamber = "H"
					end
					if row.at('td:nth(1)').inner_text == "S"
						@action_chamber = "S"
					end
					{
	          :action_chamber => @action_chamber, 
	          :action_text => row.at('td:nth(2)').inner_text, 
	          :action_date => row.at('td').inner_text
	        }
				end
			end
    end
    
    def versions
      out = []
			#no versions found yet
      out
    end
    
    def detail_page
      @detail_page ||= Hpricot(open(@detail_url))
    end
    
    def to_hash
      {
        :bill_state => 'hi',
        :bill_chamber => @chamber,
        :bill_session => @session,
        :bill_id => bill_id,
        :bill_name => name,
        :remote_url => @detail_url
      }
    end
  end
  
  def self.state
    "hi"
  end
  
  def self.scrape_bills(chamber, year)
		chamber_id = (chamber == "lower") ? "H" : "S"
		if (year.to_i < 2008)
			doc = Hpricot(open("http://www.capitol.hawaii.gov/session#{year}/status/"))
			doc.search("a").each do |link|
				if (link).inner_text =~ /^#{chamber_id}/
					bill = Bill.new("http://www.capitol.hawaii.gov/session#{year}/status/#{link.inner_text}", year, chamber)
					if (bill.eligable?)
						puts "Fetching #{bill.bill_id}"

				    common_hash = bill.to_hash
				    add_bill(common_hash)
				    common_hash.delete(:bill_name)
				    add_sponsorship(common_hash.merge(
				      :sponsor_type => 'primary', 
				      :sponsor_name => bill.primary_sponsor
				    ))
						
				    bill.actions.each do |action|
				      add_action(common_hash.merge(action))
				    end

				    # bill.versions.each do |version|
				    # 	add_bill_version(common_hash.merge(version))
				    # end
					end
				end
			end
		else			
    	doc = Hpricot(open("http://www.capitol.hawaii.gov/session#{year}/lists/intro_listSB.asp?show=all"))
    	doc.search('table/tr').each do |row|
				unless (row/"td/u/big").empty?
					
				end
			end
		end
  end
end

Hawaii.run
