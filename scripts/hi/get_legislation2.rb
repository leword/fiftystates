#!/usr/bin/env ruby
require File.join(File.dirname(__FILE__), '..', 'rbutils', 'new_legislation')
require 'hpricot'
require 'open-uri'

def copen url
  # cached open
  filekey = File.join( File.dirname(__FILE__), '..', '..', 'cache', url.gsub("http://",'').gsub("/","-") )
  if File.exists?( filekey )
    puts "cache hit: #{url} : #{filekey}"
  else
    puts "cache miss: #{url} : #{filekey}"
    open( url ) do |uri|
      File.open( filekey, "w" ) do |file|
        file.write uri.read
      end
    end
  end
  File.open( filekey )
end

class BillParser
	attr_reader :detail_page

	def initialize detail_url, year, chamber
    @detail_url, @year, @chamber = detail_url, year, chamber
    @detail_page = Hpricot(copen(@detail_url))
    raise "screwy year data" unless eligable?
  end
    
	# Determine if bill is eligable for the year requested
	def eligable?
		@eligable ||= (not (detail_page.search('table')[3].at('tr:nth(1)/td/font').inner_text =~ /[0-9]{1,2}\/[0-9]{1,2}\/#{@year}/).nil?)
	end
	
	def session
		detail_page.at('span#SessionTitle').inner_text
	end
	
	def title
		detail_page.search('table')[1].at('tr/td:nth(1)').inner_text.strip
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
		version_list = Hpricot(copen("http://www.capitol.hawaii.gov/session2009/getstatus.asp?query=#{matched[1]}#{matched[2]}&showtext=on&currpage=1"))
		version_list.search('div.monthwrapper').search('p').each do |version|				
			out << {:version_name => version.at('a').inner_text.upcase.gsub(/_\.HTM/, ""), :version_url => version.at('a:nth(1)').attributes['href']}
    end
    out
  rescue Exception=>e
    puts "Exception: #{e.message}"
    return []
  end
end




#New version of the site- this works at best from 2009 on.
class HawaiiScraper < LegislationScraper
  @@state = 'hi'
  Hpricot.buffer_size = 3456789 # Give Hpricot more buffer space for the really large ASP pages

  def scrape_bills(chamber, session)
    puts "SCRAPE #{chamber}, #{session}"
    year = session
		list_pagename = case chamber
		  when "upper"; "RptIntroSB"
	    when "lower"; "RptIntroHB"
    end
    list_url = "http://www.capitol.hawaii.gov/session#{year}/lists/#{list_pagename}.aspx"
    list_doc = Hpricot(copen(list_url))
    
		list_doc.search('table/tr')[0..5].each do |row|
			if bill_link = row.at("td:nth(3)/font/a")
			  bill_url = "http://www.capitol.hawaii.gov/session#{year}/lists/#{bill_link.attributes['href']}"
			  
			  bp = BillParser.new bill_url, year, chamber
			  bill = Bill.new session, chamber, bp.bill_id, bp.title
			  
			  bp.actions.each do |action|
			    # FIXME: 
			    bill.add_action action[:action_chamber], action[:action_text], action[:action_date]
			  end
			  
			  bp.primary_sponsor.split(",").each do |sponsor|
			    bill.add_sponsor( :primary, sponsor )
			  end
			  # bill.add_action
			  # bill.add_sponsor
			  self.add_bill bill
			end
		end
		
    # bill = Bill.new("Session 1", "upper", "SB 1", "The First Bill")
    # bill.add_sponsor("primary", "Bill Smith")
    # bill.add_sponsor("cosponsor", "John Doe"), 
    # bill.add_action("upper", "Introduced", Time.local(2009, 1, 1).to_i)
    # bill.add_version("first version", "http://example.org")
    #   
    # vote = Vote.new("upper", Time.local(2009, 1, 1).to_i, "Pass", true,
    #                 10, 3, 1)
    # vote.yes "Bill Smith"
    # vote.no "John Doe"
    #   
    # bill.add_vote vote
    # self.add_bill bill
  end

  def scrape_legislators(chamber, session)
    # implement me
  end

  def scrape_metadata
    {}
  end
end

HawaiiScraper.new.run

