# Benchmark that checks if the machine is fast enough.
# If it should ever happen that some implementation change
# slows it down, this spec will be red.

# Test state machine that loops in 3 states.

class LoopingThreeStateMachine < StateMachine::Base
	attr_accessor :steps, :loops
	attr_accessor :is_dead

  def initialize
    super(start_state: :first_state).tap do |fsm|
      fsm.steps = 0
      fsm.loops = 0

      fsm.when :first_state do |state|
        state.transition_to :second_state, on: :next,
          action: proc { @steps += 1 }
      end

      fsm.when :second_state do |state|
        state.transition_to :third_state, on: :next,
          action: proc { @steps += 1 }
      end

      fsm.when :third_state do |state|
        state.transition_to :first_state, on: :next,
          action: proc { @steps += 1; @loops += 1 }
      end
    end
  end
end

describe LoopingThreeStateMachine do
  before do
    @fsm = LoopingThreeStateMachine.new
  end

  it "should loop correctly" do
    @fsm.start!
    100.times { @fsm.event :next }
    @fsm.steps.should == 100
    @fsm.loops.should == @fsm.steps / 3
  end

  it "should prove that the state machine can handle more than 10k events per second" do
    other_queue = Dispatch::Queue.new('org.screenfashion.motion-state-machine')
    other_queue.sync { @fsm.start! }
    started_on = NSDate.date
    dispatch_group = Dispatch::Group.new
    event_count = 100000

    event_count.times do |i|
      other_queue.async(dispatch_group) { @fsm.event :next }
    end

    send_time = NSDate.date.timeIntervalSinceDate started_on

    dispatch_group.wait # wait for the events to be handled

    handle_time = NSDate.date.timeIntervalSinceDate started_on

    send_time.should < 0.2

    frequency = event_count / handle_time
    frequency.should > 10000

    puts "\nNeeded #{send_time}s to send #{event_count} events, #{handle_time}s to handle them."
    puts "That's a frequency of #{frequency} state changes per second.\n"
  end

end
