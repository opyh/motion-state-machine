# motion-state-machine

Hey, this is `motion-state-machine` — a state machine gem designed for
[RubyMotion](http://rubymotion.com) for iOS.

It features:

- A simple, nice-looking definition syntax
- Reaction to sent events, defined timeouts and global NSNotifications
- Transition guards and actions
- State entry / exit actions
- Internal transitions that don't leave the machine's current state
- Optional verbose log output for easy debugging
- [Grand Central Dispatch](https://developer.apple.com/library/mac/#documentation/Performance/Reference/GCD_libdispatch_Ref/Reference/reference.html)-awareness — uses GCD queues for synchronization

Defining a state machine looks like this:

```ruby
fsm = StateMachine::Base.new start_state: :awake

fsm.when :awake do |state|
  state.on_entry { puts "I'm awake, started and alive!" }
  state.transition_to :sleeping, on:  :finished_hard_work,
  state.die on: :too_hard_work
end
```

See below for more examples and usage instructions.

## Motivation

Undefined states and visual glitches in applications with complex UIs can
be a hassle, especially when the UI is animated and the app has to handle
asynchronous data retrieved in the background.

Well-defined UI state machines avoid these problems while ensuring that
asynchronous event handling does not lead to undefined results (a.k.a. bugs).

MacRuby and Cocoa don't provide a simple library to address this —
motion-state-machine should fill the gap for RubyMotion developers.

## Installation

1. If not done yet, add `bundler` gem management to your RubyMotion app.
   See <http://thunderboltlabs.com/posts/using-bundler-with-rubymotion> for
   an explanation how.

2. Add this line to your application's Gemfile:

   ```ruby
   gem 'motion-state-machine'
   ```

3. Execute:

   ```bash
   $ bundle
   ```

## Usage

The following example shows how to initialize and define a state machine:

```ruby
fsm = StateMachine::Base.new start_state: :working, verbose: true
```

This initializes a state machine. Calling `fsm.start!` would start the
machine in the defined start state `:working`. Using `:verbose` activates
debug output on the console.

### Defining states and transitions

After initialization, you can define states and transitions:

```ruby
fsm.when :working do |state|

  state.on_entry { puts "I'm awake, started and alive!" }
  state.on_exit { puts "Phew. That was enough work." }

  state.transition_to :sleeping,
    on:      :finished_hard_work,
    if:      proc { really_worked_enough_for_now? },
    action:  proc { puts "Will go to sleep now." }

  state.die on: :too_hard_work

end
```

This defines…

1. An entry and an exit action block, called when entering/exiting the state
   :working.

2. a transition from state `:working` to `:sleeping`, happening when calling
   `fsm.event(:finished_hard_work)`.

   Before the transition is executed, the state machine asks the `:if` guard
   block if the transition is allowed. Returning `false` in this block would
   prevent the transition from happening.

   If the transition is executed, the machine calls the given `:action` block.

3. another transition that terminates the state machine when calling
   `fsm.event(:too_hard_work)`. When terminated, the state machine stops
   responding to events.

Note that a transition from a state to itself can be _internal_: Entry/exit
actions are not called on execution in this case.

### Handling events, timeouts and NSNotifications

Transitions can be triggered…

- by calling the state machine's `#event` method (see above).

- automatically after a given timeout:
  
  ```ruby
  fsm.when :sleeping do |state|
      state.transition_to :working, after: 20
  end
  ```

  (goes back to `:working` after 20 seconds in state `:sleeping`)

- when a `NSNotification` is posted:
  ```ruby
  fsm.when :awake do |state|
  state.transition_to :in_background,
      on_notification: UIApplicationDidEnterBackgroundNotification
  end
  ```

### How fast is it?

The implementation is designed for general non-performance-intensive purposes
like managing UI state behavior. It may be too slow for parsing XML, realtime
signal processing with high sample rates and similar tasks.

Anyways, it should be able to handle several thousand events per second on
an iOS device.

## Contributing

Feel free to fork the project and send me a pull request if you would
like me to integrate your bugfix, enhancement, or feature.

You can easily add new triggering mechanisms — they can be
implemented in few lines by subclassing the `Transition` class (see
the implementation of `NotificationTransition` for an example).

I'm also open for suggestions regarding the interface design.

To contribute,

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

If the feature has specs, I will probably merge it :)
