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
  describe ".vote" do
    it "returns nuthin for a non-voting action" do
      ActionParser.vote( "no action").should == nil
    end

    describe "senate vote" do
      before do
        action = "The committee(s) on TIA recommend(s) that the measure be PASSED, "+
          "WITH AMENDMENTS. The votes in TIA were as follows: 4 Aye(s): " +
          "Senator(s) Gabbard, Espero, Nishihara; Aye(s) with reservations: "+
          "Senator(s) English ; 1 No(es): Senator(s) Slom; and 0 Excused: none."
        @vote = ActionParser.vote( { :chamber => "upper", :date=>Time.now, :text=>action })
      end
      
      it("gets chamber") { @vote[:chamber].should == "upper" }
      it("gets yes_count") { @vote[:yes_count].should == 4     }
      it("gets no_count") { @vote[:no_count].should == 1      }
      it("gets other_count") { @vote[:other_count].should == 0   }
      it("gets extra body") { @vote[:body].should == "TIA" }
      it("gets yes votes") { @vote[:yes_votes].should == ["Gabbard", "Espero", "Nishihara","English"] }
      it("gets no votes") { @vote[:no_votes].should == ["Slom"] }
      it("gets outcome") { @vote[:outcome].should == "PASSED, WITH AMENDMENTS"  }
        
    end
    
    it "creates a house vote" do
      action = "The committees on WLO recommend that the measure be PASSED, WITH AMENDMENTS. " + 
        "The votes were as follows: 11 Ayes: Representative(s) Ito, Har, Cabanilla, Chang, Chong, " +
        "Coffman, Herkes, C. Lee, Morita, Sagum, Ching; Ayes with reservations: none; 1 Noes: " +
        "Representative(s) Thielen; and 1 Excused: Representative(s) Luke."
      vote = ActionParser.vote( { :chamber => "lower", :date=>Time.now, :text=>action })
      vote[:chamber].should == "lower"
      vote[:yes_count].should == 11
      vote[:no_count].should == 1
      vote[:other_count].should == 1
    end
  end
  
  describe ".committee_referral" do
  
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
end
