describe StateMachine::Transition do
  before do
    @state_machine = StateMachine::Base.new start_state: :awake
    @source_state = @state_machine.state :awake
    @destination_state = @state_machine.state :tired
    @options = {
      state_machine: @state_machine,
      from: :awake,
      to: :tired,
      on: :work_done
    }
    StateMachine::Transition.event_type = :on
  end

  describe "#initialize(options)" do
    it "should not raise if correctly initialized" do
      proc {StateMachine::Transition.new @options}.should.not.raise
    end

    it "should raise if it should be internal, but source state != destination state" do
      @options[:from].should != @options[:to]
      proc {StateMachine::Transition.new @options.merge(internal: true)}.
        should.raise ArgumentError, /Internal/
    end
  end

  describe "after initialization" do
    before do
      @transition = StateMachine::Transition.new @options
    end

    describe "#allowed?" do
      it "should be true if no guard blocks are given" do
        @transition.should.be.allowed
      end

      it "should have the correct logic results according to a logic table" do
        #  :unless  :if     allowed?
        {
          [nil,     nil]    => true,
          [nil,     false]  => false,
          [nil,     true]   => true,
          [false,   nil]    => true,
          [false,   false]  => false,
          [false,   true]   => true,
          [true,    nil]    => false,
          [true,    false]  => false,
          [true,    true]   => false,
        }.each do |guards, result|
          transition = StateMachine::Transition.new @options.dup
          transition.options[:unless] = proc {guards[0]} unless guards[0].nil?
          transition.options[:if]     = proc {guards[1]} unless guards[1].nil?
          transition.allowed?.should == result
        end
      end

    end

    describe "#unguarded_execute" do
      it "should call its source state's exit method if not internal" do
        exit_action_called = false
        @state_machine.when(:awake) do |state|
          state.on_exit do
            exit_action_called = true
          end
        end
        @state_machine.start!
        exit_action_called.should == false
        @transition.send :unguarded_execute
        exit_action_called.should == true
      end

      it "should not call its source state's exit method if internal" do
        @transition.options[:internal] = true
        exit_action_called = false
        @state_machine.when(:awake) do |state|
          state.on_exit do
            exit_action_called = true
          end
        end
        @state_machine.start!
        exit_action_called.should == false
        @transition.send :unguarded_execute
        exit_action_called.should == false
      end

      it "should call its destination state's enter method if not internal" do
        entry_action_called = false
        @state_machine.when(:tired) do |state|
          state.on_entry do
            entry_action_called = true
          end
        end
        @state_machine.start!
        entry_action_called.should == false
        @transition.send :unguarded_execute
        entry_action_called.should == true
      end

      it "should not call its destination state's enter method if internal" do
        @transition.options[:internal] = true
        entry_action_called = false
        @state_machine.when(:tired) do |state|
          state.on_entry do
            entry_action_called = true
          end
        end
        @state_machine.start!
        entry_action_called.should == false
        @transition.send :unguarded_execute
        entry_action_called.should == false
      end

      it "should call its action block if given" do
        called = false
        argument = nil
        @transition.options[:action] = proc do |state_machine|
          called = true
          argument = state_machine
        end
        @state_machine.start!
        called.should == false
        @transition.send :unguarded_execute
        called.should == true
        argument.should == @state_machine
      end

      it "should not be guarded, but directly execute" do
        @transition.options[:if] = proc { false }
        @transition.options[:unless] = proc { true }
        @state_machine.start!
        @state_machine.current_state.symbol.should == :awake
        @transition.send :unguarded_execute
        @state_machine.current_state.symbol.should == :tired
      end
    end

    describe "#handle_in_source_state" do
      it "should raise if called before the state machine is started" do
        @state_machine.current_state.symbol.should == :waiting_for_start
        proc {@transition.send :handle_in_source_state}.
        should.raise RuntimeError, /started/
      end

      it "should raise if called outside the initial queue" do
        @state_machine.start!
        other_queue = Dispatch::Queue.concurrent(:default)
        other_queue.to_s.should != Dispatch::Queue.main.to_s
        other_queue.sync do
          proc {@transition.send :handle_in_source_state}.should.raise RuntimeError, /queue/
        end
        @state_machine.current_state.symbol.should == :awake
      end
    end
  end

end
