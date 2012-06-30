describe StateMachine::SendEventTransition do
  before do
    @state_machine = StateMachine::Base.new start_state: :awake
    @source_state = @state_machine.state :awake
    @destination_state = @state_machine.state :tired
    @options = {
      state_machine: @state_machine,
      from: :awake,
      to: :tired,
      type: :on,
      on: :work_done
    }
    @transition = StateMachine::Transition.make @options
  end

  it "should correctly register in the factory" do
    @transition.should.is_a(StateMachine::SendEventTransition)
  end

  describe "#initialize(options)" do
    it "should not arm the transition" do
      @state_machine.event(:work_done)
      @state_machine.current_state.symbol.should == :waiting_for_start
    end
  end

  describe "#arm" do
    it "should execute the transition when the event is sent to the state machine" do
      @state_machine.start!
      @state_machine.current_state.symbol.should == :awake
      @state_machine.event(:work_done)
      @state_machine.current_state.symbol.should == :awake
      @transition.arm
      # necessary for the event to work
      @source_state.register(@transition)
      @state_machine.event(:work_done)
      @state_machine.current_state.symbol.should == :tired
    end
  end

  describe "#unarm" do
    it "should make sure the transition is not executed when the event is sent to the state machine" do
      transition = StateMachine::Transition.make @options
      @state_machine.start!
      @state_machine.current_state.symbol.should == :awake
      @transition.unarm
      @source_state.register(@transition)
      @state_machine.event(:work_done)
      @state_machine.current_state.symbol.should == :awake
    end
  end

end
