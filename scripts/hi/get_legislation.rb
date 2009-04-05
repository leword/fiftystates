#!/usr/bin/ruby

require File.join(File.dirname(__FILE__), '..', 'rbutils', 'legislation')
module Hawaii  
  include Scrapable
  
  class LegacyBill
    attr_reader :session
		def initialize(detail_url, year, chamber)
			puts "Starting legacy bill with #{detail_url}"
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
					nil
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
			end.compact
    end
    
    def versions
			@name = name.gsub(/\s+/, "_")
      [{:version_name => "Full Text", :version_url => "http://www.capitol.hawaii.gov/session#{@year}/bills/#{@bill_id}.pdf"}]
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

	class Bill
		attr_reader :session
		def initialize(detail_url, year, chamber)
      @year = year
			@chamber = chamber
			@detail_url = detail_url
    end
    
		# Determine if bill is eligable for the year requested
		def eligable?
			@eligable ||= (not (detail_page.search('table')[3].at('tr:nth(1)/td/font').inner_text =~ /[0-9]{1,2}\/[0-9]{1,2}\/#{@year}/).nil?)
		end
		
		def session
			detail_page.at('span#SessionTitle').inner_text
		end
		
		def name
			detail_page.search('table')[1].at('tr/td:nth(1)').inner_text
		end

    def bill_id
      detail_page.at('a#LinkButtonMeasure').inner_text
    end
    
    def primary_sponsor
      detail_page.search('table')[2].at('tr/td:nth(1)').inner_text.strip
    end

		def actions
			detail_page.search('table')[3].search('tr').collect do |row|
				if row.at('td').nil?
					nil
				else
					@action_chamber = ""
					if row.at('td:nth(1)/font').inner_text == "H"
						@action_chamber = "H"
					end
					if row.at('td:nth(1)/font').inner_text == "S"
						@action_chamber = "S"
					end
					{
	          :action_chamber => @action_chamber, 
	          :action_text => row.at('td:nth(2)/font').inner_text, 
	          :action_date => row.at('td/font').inner_text
	        }
				end
			end.compact
    end
    
    def versions
			out = []
			matched = @detail_url.match(/billtype=([^&]+)&billnumber=(.+)$/)
			version_list = Hpricot(open("http://www.capitol.hawaii.gov/site1/docs/getstatus.asp?query=#{matched[1]}#{matched[2]}&showtext=on&currpage=1"))
			version_list.search('div.monthwrapper').search('p').each do |version|
				
				out << {:version_name => version.at('a').inner_text.upcase.gsub(/_\.HTM/, ""), :version_url => version.at('a:nth(1)').attributes['href']}
      end
      out
    end
    
    def detail_page
      @detail_page ||= Hpricot(open(@detail_url))
    end
    
    def to_hash
      {
        :bill_state => 'hi',
        :bill_chamber => @chamber,
        :bill_session => session,
        :bill_id => bill_id,
        :bill_name => name.strip,
        :remote_url => @detail_url
      }
    end
		
	end
  
  def self.state
    "hi"
  end
  
  def self.scrape_bills(chamber, year)
		if (year.to_i < 2008)
			if chamber.nil?
				chamber_ids = ["S", "H"] 
			else
				chamber_ids = (chamber == "lower") ? ["S"] : ["H"]
			end
			puts "Searching archives"
			#search the archives
			doc = Hpricot(open("http://www.capitol.hawaii.gov/session#{year}/status/"))
			doc.search("a").each do |link|
				chamber_ids.each do |id|
					if (link).inner_text =~ /^#{id}/
						bill = LegacyBill.new("http://www.capitol.hawaii.gov/session#{year}/status/#{link.inner_text}", year, chamber)
						process_bill(bill)
					end
				end
			end
		elsif year.to_i == 2008
			if (chamber != "upper")	
				doc = Hpricot(open("http://www.capitol.hawaii.gov/session2008/lists/intro_listHB_pf_all.htm"))
				doc.search('table/tr').each do |row|
					unless row.at('td').nil?
						matched = row.at('td').inner_text.match(/href="([^"]+)"/)
						unless matched.nil?
							bill = LegacyBill.new(matched[1], year, "lower")
							process_bill(bill)
						end
					end
				end
			end
			if (chamber != "lower")
				doc = Hpricot(open("http://www.capitol.hawaii.gov/session2008/lists/intro_listSB_pf_all.htm"))
				doc.search('table/tr').each do |row|
					unless row.at('td').nil?
						matched = row.at('td').inner_text.match(/href="([^"]+)"/) 
						unless matched.nil?
							bill = LegacyBill.new(matched[1], year, "upper")
							process_bill(bill)
						end
					end
				end
			end
		else
			puts "Searching current"
			Hpricot.buffer_size = 3456789 # Give Hpricot more buffer space for the really large ASP pages
			#New version of the site
			if (chamber != "upper")			
    		doc = Hpricot(open("http://www.capitol.hawaii.gov/session#{year}/lists/RptIntroHB.aspx"))
				puts "Starting page search"
	    	doc.search('table/tr').each do |row|
					unless (row.at("td:nth(3)/font/a")).nil?
						bill = Bill.new("http://www.capitol.hawaii.gov/session#{year}/lists/#{row.at("td:nth(3)/font/a").attributes['href']}", year, "lower")
						process_bill(bill)
					end
				end
			end
			if (chamber != "lower")
				doc = Hpricot(open("http://www.capitol.hawaii.gov/session#{year}/lists/RptIntroSB.aspx"))
				doc.search('table/tr').each do |row|
					unless (row.at("td:nth(3)/font/a")).nil?
						bill = Bill.new("http://www.capitol.hawaii.gov/session#{year}/lists/#{row.at("td:nth(3)/font/a").attributes['href']}", year, "upper")
						process_bill(bill)
					end
				end
			end
		end
  end
	
	def self.process_bill(bill)
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

	    bill.versions.each do |version|
	    	add_bill_version(common_hash.merge(version))
	    end
		else
			puts "Bill #{bill.name} not eligable"
		end
	end
end

Hawaii.run
