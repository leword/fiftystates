# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
require 'rubygems'
require 'spec'
require 'ruby-debug'
require File.expand_path(File.dirname(__FILE__)+'/get_legislation2.rb')


describe BillParser do
  before do
    sample_file = File.join( File.dirname(__FILE__), "sample_bill.html")
    @bp = BillParser.new( sample_file, 2010, "upper")
  end
  
  it "gets the title" do
    @bp.title.should == "RELATING TO FIREWORKS."
  end
  
  it "gets current committee" do
    @bp.extra[:committee].should == ["JGO"]
  end
end


describe ActionParser do
  it "returns nuthin for a dumb action" do
    ActionParser.committee_referral( "no action").should == nil
  end
  
  it "recognizes a new referral list" do
    action = 'Referred to HTH/LBR, WAM'
    ActionParser.committee_referral(action).should == ['HTH','LBR']
    
    action = 'Referred to EEP/WLO, JUD, FIN, referral sheet 1'
    ActionParser.committee_referral(action).should == ['EEP','WLO']
  end
  
  it "recognizes a referral update" do
    action = 'Passed Second Reading as amended in HD 1 and referred to ' +
     'the committee(s) on JUD with none voting no (0) and Pine, Takai excused (2)'
    ActionParser.committee_referral(action).should == ['JUD']
    
    action = 'Report adopted; Passed Second Reading, as amended (SD 1) and referred to JGO.'
    ActionParser.committee_referral(action).should == ['JGO']
  end
end
