describe StateMachine::TimedTransition do

  before do
    @count = 0
    @state_machine = StateMachine::Base.new start_state: :timing_out
    action = proc { @fired = true; @count = @count + 1 }
    @state_machine.when :timing_out do |state|
      @transition = state.transition_to(:timed_out, after: 0.5, action: action).first
      state.transition_to :cancelled, on: :cancel
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

    it "executes at the given time if not cancelled" do
      sleep 0.49
      @state_machine.current_state.symbol.should == :timing_out
      @fired.should == false
      sleep 0.02
      @state_machine.current_state.symbol.should == :timed_out
      @fired.should == true
    end

    it "is not executed if leaving the state before timeout" do
      sleep 0.49
      @fired.should == false
      @other_queue.async do
        @state_machine.event :cancel
      end
      sleep 0.02
      @state_machine.current_state.symbol.should == :cancelled
      @fired.should == false
    end

    it "does not repeat (regression test)" do
      sleep 0.49
      @state_machine.current_state.symbol.should == :timing_out
      sleep 0.02
      @state_machine.current_state.symbol.should == :timed_out
      sleep 1.0
      @count.should == 1
    end
  end

end
