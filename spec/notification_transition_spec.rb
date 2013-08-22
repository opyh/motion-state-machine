describe StateMachine::NotificationTransition do

  before do
    @state_machine = StateMachine::Base.new start_state: :awaiting_notification
    action = proc {@fired = true}
    @state_machine.when :awaiting_notification do |state|
      @transition = state.transition_to(:notified, on_notification: "SomeNotification", action: action).first
      state.transition_to :canceled, on: :cancel
    end
  end

  it "should be created correctly" do
    @transition.should.is_a(StateMachine::NotificationTransition)
  end

  describe "when running in main queue" do
    it "should be executed when receiving the notification and unarm correctly" do
      @fired = false
      @state_machine.start! # will arm the transition
      @state_machine.current_state.symbol.should == :awaiting_notification
      @fired.should == false

      NSNotificationCenter.defaultCenter.postNotificationName "SomeNotification", object: nil
      @state_machine.current_state.symbol.should == :notified
      sleep 0.1
      @fired.should == true
      @fired = false

      NSNotificationCenter.defaultCenter.postNotificationName "SomeNotification", object: nil
      @state_machine.current_state.symbol.should == :notified
      sleep 0.1
      @fired.should == false
    end
  end

  describe "when running in other queue" do
    it "should be executed when receiving the notification and unarm correctly" do
      @fired = false

      other_queue = Dispatch::Queue.concurrent
      other_queue.sync do
        @state_machine.start! # will arm the transition
      end
      @state_machine.current_state.symbol.should == :awaiting_notification
      @fired.should == false

      NSNotificationCenter.defaultCenter.postNotificationName "SomeNotification", object: nil
      sleep 0.1
      @state_machine.current_state.symbol.should == :notified
      @fired.should == true
      @fired = false

      NSNotificationCenter.defaultCenter.postNotificationName "SomeNotification", object: nil
      @state_machine.current_state.symbol.should == :notified
      @fired.should == false
    end
  end

end
