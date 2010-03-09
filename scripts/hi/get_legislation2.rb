#!/usr/bin/env ruby
require File.join(File.dirname(__FILE__), '..', 'rbutils', 'new_legislation')
require 'hpricot'
require 'open-uri'
require 'ruby-debug'

def copen url
  # cached open
  if url =~ /^http:/
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
  else
    filekey = url
  end
  File.open( filekey )
end

class ActionParser
  def self.committee_referral( action_text  )
    if m = action_text.match(/eferred to[^A-Z]*([A-Z\,\s\/]+)/) 
      #left off "r" because sometimes upper case sometimes lower
      m[1].split(/[\s,]+/).compact.first.split('/')
      # first clean list of committees, then clean first one or pair
    end
  end
  
  def self.vote( action )
    if action[:text] =~ /^The committee.*on (.+) recommend.*that the measure be (.+). The votes.*were as follows:(.*).$/
      motion, passed, yes_count, no_count, other_count = "","",0,0,0
      extra = {
        :body => $~[1],
        :outcome => $~[2],
        :yes_votes => [],
        :no_votes => [],
        :other_votes => []
      }

      vote_strings = $~[3].split(';')
      vote_strings.each do |vs|
        if vs.gsub(/and /,'').match(  / ((\d+) )?([^:]+): \w+\(s\) (.*)/ )
          count, kind, names = ($~[2] || 0).to_i, $~[3], $~[4].split(", ").map(&:strip)
          case kind
            when /aye/i
              yes_count += count;
              extra[:yes_votes] += names
            when /no/i
              no_count += count;
              extra[:no_votes] += names
            else
              other_count += count
              extra[:other_votes] += names
          end
        end
      end

      Vote.new( action[:chamber], action[:date], motion, passed, yes_count, no_count, other_count, extra )
    end
  end
  
  #def initialize(chamber, date, motion, passed, yes_count, no_count,
  #               other_count, extra={})
  
end

class BillParser
	attr_reader :detail_page

	def initialize detail_url, year, chamber
    @detail_url, @year, @chamber = detail_url, year, chamber
    @detail_page = Hpricot(copen(@detail_url))
    #debugger
    #raise "screwy year data" unless eligable?
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

  # extra fields
  def main_table n
    detail_page.search('table')[1].at("tr:nth(#{n})/td:nth(1)").inner_text.strip
  end

  def extra
    {
      :report_title => main_table(1),
      :description => main_table(2),
      :companion => main_table(3),
      :package => main_table(4),
      :current_referral => main_table(5),
      :committee => actions.map{|a| ActionParser.committee_referral( a[:text] ) }.compact.last
    }
  end

	def actions
		detail_page.search('table')[3].search('tr').collect do |row|
			if row.at('td').nil?
				nil
			else
				c = row.at('td:nth(1)/font').inner_text
				@action_chamber = ["H","S"].include?(c) ? c : ""
				{
          :chamber => @action_chamber, 
          :text => row.at('td:nth(2)/font').inner_text, 
          :date => row.at('td/font').inner_text
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
    
		list_doc.search('table/tr').each do |row|
			if bill_link = row.at("td:nth(3)/font/a")
			  bill_url = "http://www.capitol.hawaii.gov/session#{year}/lists/#{bill_link.attributes['href']}"
			  
			  bp = BillParser.new bill_url, year, chamber
			  bill = Bill.new session, chamber, bp.bill_id, bp.title, bp.extra
			  
			  bp.actions.each do |action|
			    # FIXME: 
			    bill.add_action action[:chamber], action[:text], action[:date]
			    if vote = ActionParser.vote( action )
			      bill.add_vote vote
		      end
			  end
			  
			  bp.primary_sponsor.split(",").each do |sponsor|
			    bill.add_sponsor( :primary, sponsor.gsub(/\(br\)/i,"").strip )
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

