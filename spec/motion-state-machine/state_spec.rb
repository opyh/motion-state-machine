describe StateMachine::State do
  before do
    @living = StateMachine::State.new "stub", symbol: :awake, name: "Living"
  end
  
  describe "Entering/exiting" do
    before do
      # These seem not to be correctly deinitialized after single specs,
      # so we have to reinitialize them ourselves.
      
      @entry_action_called = false
      @other_entry_action_called = false
      @exit_action_called = false
      @other_exit_action_called = false
      
      @state_machine = StateMachine::Base.new start_state: :awake
      @state_machine.when(:awake) do |state|
        state.transition_to :tired, on: :work_done
        state.on_exit do
          @exit_action_called = true
        end
        state.on_exit do
          @other_exit_action_called = true
        end
      end
      @state_machine.when(:tired) do |state|
        state.transition_to :very_excited, on: :something_happened
        state.on_entry do
          @entry_action_called = true
        end
        state.on_entry do
          @other_entry_action_called = true
        end
      end
      
      @state_machine.start!
      @state_machine.current_state.symbol.should == :awake
    end

    describe "#enter!" do
      it "should set the state machine's current state" do
        @state_machine.state(:tired).send :enter!
        @state_machine.current_state.symbol.should == :tired      
      end
    
      it "should execute the entry actions" do
        @entry_action_called.should == false
        @other_entry_action_called.should == false
        @state_machine.event(:work_done)
        @entry_action_called.should == true
        @other_entry_action_called.should == true
      end
      
      it "should arm the transitions" do
        @state_machine.event(:something_happened) # should be ignored
        @state_machine.current_state.symbol.should == :awake      
        @state_machine.event(:work_done)
        @state_machine.current_state.symbol.should == :tired
        @state_machine.event(:something_happened)
        @state_machine.current_state.symbol.should == :very_excited
      end
      
    end
    
    describe "#exit!" do
      it "should set the state machine's current state to nil" do
        @state_machine.state(:awake).send :exit!
        @state_machine.current_state.should == nil
      end
    
      it "should execute the exit actions" do
        @exit_action_called.should == false
        @other_exit_action_called.should == false
        @state_machine.event(:work_done)
        @exit_action_called.should == true
        @other_exit_action_called.should == true
      end
      
      it "should unarm the transitions" do
        @state_machine.state(:awake).send :exit!
        @state_machine.event(:work_done) # should be ignored
        @state_machine.current_state.should == nil
      end
    end
    
  end
  
  describe "#guarded_execute(options)" do
    before do
      @state_machine = StateMachine::Base.new start_state: :awake
    end
    it "should not do anything when on a terminating state" do
      @state_machine.when :awake do |state|
        state.die on: :kill
      end
      @state_machine.start!
      @state_machine.current_state.symbol.should == :awake
      @state_machine.current_state.send :guarded_execute, :on, :kill
      @state_machine.current_state.should.be.terminating
    end

    describe ":if and :unless guards" do
      
      # if/unless logic table is tested in transition specs
      
      it "should raise if multiple non-guarded transitions would be possible for the same event" do
        @state_machine.when :awake do |state|
          state.transition_to :state2, on: :work_done
          state.transition_to :state3, on: :work_done
        end
        @state_machine.start!
        lambda {@state_machine.current_state.send :guarded_execute, :on, :work_done}.should.raise RuntimeError
      end

      it "should raise if multiple guarded transitions would be possible for the same event" do
        @state_machine.when :awake do |state|
          state.transition_to :state2, on: :work_done, :if => proc { true }
          state.transition_to :state3, on: :work_done, :if => proc { true }
        end
        @state_machine.start!
        lambda {@state_machine.current_state.send :guarded_execute, :on, :work_done}.should.raise RuntimeError
      end

      it "should execute right transition of multiple are allowed" do
        @state_machine.when :awake do |state|
          state.transition_to :state2, on: :work_done, :if => proc { false }
          state.transition_to :state3, on: :work_done, :if => proc { true }
        end
        @state_machine.start!
        @state_machine.current_state.send :guarded_execute, :on, :work_done
        @state_machine.current_state.symbol.should == :state3
      end
    
      it "should not execute any transition if all are disallowed" do
        @state_machine.when :awake do |state|
          state.transition_to :state2, on: :work_done, :if => proc { false }
          state.transition_to :state3, on: :work_done, :if => proc { false }
        end
        @state_machine.start!
        @state_machine.current_state.send :guarded_execute, :on, :work_done
        @state_machine.current_state.symbol.should == :awake
      end

    end
    
  end
  
  describe "Definition DSL" do
    before do
      @state_machine = StateMachine::Base.new start_state: :awake
    end

    describe "#transition_to" do
      it "should return an array of created transitions" do
        @state_machine.when(:awake) do |state|
          transitions = state.transition_to(:tired, after: 42)
          transitions.class.should == Array
          transitions.first.class.should == StateMachine::TimedTransition
        end
      end
        
      describe "Argument error handling" do
        it "should raise if not given a destination state symbol" do
          proc do
            @state_machine.when(:awake) do |state|
              state.transition_to Hash.new, on: :eat
            end
          end.should.raise ArgumentError, /No destination state given/
        end
  
        it "should raise if not given a trigger event" do
          proc do
            @state_machine.when(:awake) do |state|
              state.transition_to :sleepy
            end
          end.should.raise ArgumentError, /No trigger event/          
        end
          
        it "should create the destination state if not existent" do
          created = proc {@state_machine.states.collect(&:symbol).include?(:sleepy)}
          created.call.should == false
          @state_machine.when(:awake) do |state|
            state.transition_to :sleepy, on: :hard_work_done
          end          
          created.call.should == true          
        end
      end
    end
      
    describe "#die" do
      it "should return an array of created transitions" do
        @state_machine.when(:awake) do |state|
          transitions = state.die(on: :eat)
          transitions.class.should == Array
          transitions.first.class.should == StateMachine::SendEventTransition
        end
      end
        
      it "should create termination states with different symbols" do
        @state_machine.when(:awake) do |state|
          # so many options!
          transitions1 = state.die on: :suffocation
          transitions2 = state.die on: :starving
          transitions1.first.destination_state.symbol.should != transitions2.first.destination_state.symbol
        end
      end
        
      it "should set the termination states' terminating flags" do
        @state_machine.when(:awake) do |state|
          non_terminating_transitions = state.transition_to :tired, on: :work_done
          terminating_transitions = state.die on: :suffocation
          non_terminating_transitions.first.destination_state.should.not.be.terminating
          terminating_transitions.first.destination_state.should.be.terminating
        end        
      end
    end
  end
  
end