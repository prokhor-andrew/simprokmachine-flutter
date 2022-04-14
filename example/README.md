# EXAMPLE

Machine - is an instance in your application that receives and processes input data and may emit output.

![concept](https://github.com/simprok-dev/simprokmachine-flutter/blob/main/images/simprokmachine.drawio.png)

To create it use ```ChildMachine``` class.

```Dart
class PrinterMachine extends ChildMachine<String, bool> {
    
    @override
    void process(String? input, Handler<bool> callback) {
        log(input);
    }
}
```

If your machine must update flutter widgets with its input - use ```ChildWidgetMachine``` instead. Combine it with ```MachineConsumer``` to update UI where needed.

```Dart
class PrinterWidgetMachine extends ChildWidgetMachine<String, bool> {

    @override
    Widget child() {
      return MaterialApp( 
          home: Scaffold(
            body: Center(
              child: MachineConsumer<String, bool>(
                initial: (BuildContext context) => Text("UI before first input was received"),
                builder: (BuildContext context, String? input, Handler<bool> callback) => Text("UI when input received: $input")
              ),
            ),
          ),
      ),
    }
}
```


To start the flow use ```runRootMachine()``` method in your ```main()``` function.

```Dart
void main() {

    runRootMachine<String, bool>(
        root: PrinterWidgetMachine(),
    );
}
```

This does not print anything but ```null``` because after ```startRootMachine()``` is called the root is subscribed to the child machine triggering ```process()``` method with ```null``` value.

Use ```Handler<Output> callback``` to emit output. 

```Dart
class EmittingMachine extends ChildMachine<String, bool> {
    
    void process(String? input, Handler<bool> callback) {
        if (input != null) { 
            log("input: \(input)");
        } else {
            callback(false); // Emits output
        }
    }
}
```

Standard implementations of ```ChildMachine``` are ```BasicMachine``` and ```ProcessMachine```.

```Dart
final machine = BasicMachine<int, bool>((int? input, Handler<bool> callback) {
    // handle input here
    // emit outuput if needed
});
```

and

```Dart
final machine = ProcessMachine<int, bool>(this, (thisObject, int? input, bool callback) { 
    // handle input here
    // emit outuput if needed
});
```

And there is also an implementation of ```BasicWidgetMachine``` if you want to inject your widget without extra classes.

```Dart
final machine = BasicWidgetMachine<int, bool>(child: MyAppWidget());
```

To unite two or more machines where one machine is ```WidgetMachine``` and another one is plain ```Machine``` use ```mergeWidgetMachine()```.

```Dart
void main() {

    runRootMachine<String, bool>(
        root: mergeWidgetMachine(
          main: PrinterWidgetMachine(),
          secondary: { PrinterMachine(), },
        ), 
    );
}
```

To merge more than one machine together - use ```merge()```.

```Dart
final Machine<Input, Output> machine1 = ...
final Machine<Input, Output> machine2 = ...

... = merge({
    machine1,
    machine2,
});
```

To separate machines into classes instead of cluttering them up in the ```runRootMachine()```, use ```ParentMachine``` or ```ParentWidgetMachine``` classes.

```Dart
class IntermediateLayer extends ParentMachine<String, bool> {

    @override
    Machine<String, bool> child() {
        return PrinterMachine(); // or PrinterWidgetMachine() if extends ParentWidgetMachine
    }
}
```


To map or ignore input - use ```inward()```.

```Dart
... = machine.inward((ParentInput parentInput) {
    return Ward.values([ChildInput(), ChildInput(), ChildInput()]); // pass zero, one or more outputs.
})
```


To map or ignore output - use ```outward()```. 

```Dart
... = machine.outward((ChildOutput childOutput) {
    return Ward.values([ParentOutput(), ParentOutput(), ParentOutput()]); // pass zero, one or more outputs.
});
```

To send input back to the child when output received - use ```redirect()```.

```Dart
... = machine.redirect((ChildOutput childOutput) { 
    // Return 
    // Direction.prop() - for pushing ChildOutput further to the root.
    // Direction.back(Ward.values([ChildInput()])) - for sending child inputs back to the child.
    ...
});
```


To dynamically create and connect machines when new input received - use ```ConnectableMachine```.

```Dart
... = ConnectableMachine<int, bool, BasicConnection<int, bool>>.create(
    BasicConnection({
        MyMachine1(), 
        MyMachine2(),
    }), 
    (BasicConnection<int, bool> state, int input) { 
        // Return 
        // ConnectionType<int, bool, BasicConnection<int, bool>>.reduce(BasicConnection<int, bool>({})) - when new machines have to be connected.
        // ConnectionType<int, bool, BasicConnection<int, bool>>.inward() - when existing machines have to receive input: Int
    }
); 
```

Check out the [sample](https://github.com/simprok-dev/simprokmachine-flutter/tree/main/sample) and the [wiki](https://github.com/simprok-dev/simprokmachine-flutter/wiki) for more information about API and how to use it.

