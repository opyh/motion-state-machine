describe StateMachine::TimedTransition do
  
  before do
    @state_machine = StateMachine::Base.new start_state: :timing_out
    action = proc { @fired = true }
    @state_machine.when :timing_out do |state|
      @transition = state.transition_to(:timed_out, after: 0.5, action: action).first
      state.transition_to :canceled, on: :cancel
    end
  end
  
  it "should be created correctly" do
    @transition.should.is_a(StateMachine::TimedTransition)
  end
  
  describe "after entering the state that is timing out" do
    before do
      @fired = false
      @other_queue = Dispatch::Queue.concurrent :default
      @other_queue.sync do
        @state_machine.start! # will arm the transition
      end
      @state_machine.current_state.symbol.should == :timing_out
      @fired.should == false      
    end
    
    it "it should execute at the given time if not cancelled" do
      sleep 0.49
      @state_machine.current_state.symbol.should == :timing_out
      @fired.should == false
      sleep 0.02
      @state_machine.current_state.symbol.should == :timed_out
      @fired.should == true
    end

    it "should not execute if leaving the state before timeout" do
      sleep 0.49
      @fired.should == false
      @other_queue.async do
        @state_machine.event :cancel
      end
      sleep 0.02
      @state_machine.current_state.symbol.should == :canceled
      @fired.should == false
    end
  end  

end
