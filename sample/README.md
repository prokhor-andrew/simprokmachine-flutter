# [simprokmachine](https://github.com/simprok-dev/simprokmachine-flutter) sample

## Introduction

This sample is created to showcase the main features of the framework. 


It is hard to demonstrate the functionality of ```simprokmachine``` without an example as the concept behind it affects the way you design, plan and code your application.


The sample is divided into 13 easy steps demonstrating the flow of the app development and API usage.



## Disclaimer

This sample's main idea is to showcase classes, operators and how to use them. It is more about "how to do" instead of "what to do". 


Neither it guarantees that everything here could or should be used in a real life project nor it forces you into using any certain ideas. 


To see our recommended architecture check our [simprokcore framework](https://github.com/simprok-dev/simprokcore-flutter).



## Step 0 - Describe application's behavior

Let's assume we want to create a counter app that shows a number on the screen and logcat each time it is incremented. 


When we reopen the app we want to see the same number. So the state must be saved in a persistent storage. 


## Step 1 - Describe application's components


- ```MyApp``` - flutter widget.
    - Input: String
    - Output: VoidEvent
- ```Logger``` - printing the number.
    - Input: String
    - Output: void
- ```StorageReader``` - reading from ```SharedPreferences```.
    - Input: VoidEvent
    - Output: int
- ```StorageWriter``` - writing to ```SharedPreferences```.
    - Input: int
    - Output: void
- ```Calculator``` - incrementing the number.
    - Input: VoidEvent
    - Output: int


![Components](https://github.com/simprok-dev/simprokmachine-flutter/blob/main/sample/images/components1.drawio.png)




## Step 2 - Describe data flows

Build a complete tree of all machines to visualize the connections.

![A tree](https://github.com/simprok-dev/simprokmachine-flutter/blob/main/sample/images/components2.drawio.png)


Three instances that we haven't talked about are:
- ```Window```
    - Input: String
    - Output: VoidEvent
- ```Display``` 
    - Input: AppEvent
    - Output: AppEvent
- ```Domain```
    - Input: AppEvent
    - Output: AppEvent

They are used as intermediate layers. 


```AppEvent``` is a custom type for communication between ```Domain``` and ```Display```.


## Step 3 - Code data types

We only need ```VoidEvent``` and ```AppEvent``` as the rest is supported by Dart.


```Dart
class VoidEvent {}
```

```Dart
class AppEvent {
  final int? didChangeState;

  AppEvent.willChangeState() : didChangeState = null;

  AppEvent.didChangeState(int number) : didChangeState = number;

  @override
  String toString() {
    return didChangeState != null
        ? "did change state: $didChangeState"
        : "will change state";
  }
}
```
        
## Step 4 - Code Logger


```Dart
class Logger extends ChildMachine<String, void> {
  @override
  void process(String? input, Handler<void> callback) {
    log(input ?? "loading");
  }
}
```

[ChildMachine](https://github.com/simprok-dev/simprokmachine-flutter/wiki/ChildMachine) - is a container for your logic. It accepts input and handles it. When needed - emits output.


## Step 5 - Code MyApp widget

Code a ```MyApp``` widget.

```Dart
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Counter app'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            MachineConsumer<String, VoidEvent>(
              initial: (BuildContext context) => Text(
                "initial",
                style: Theme.of(context).textTheme.headline4,
              ),
              builder: (BuildContext context, String? msg,
                  Handler<VoidEvent> callback) {
                return Text(
                  msg ?? "loading",
                  style: Theme.of(context).textTheme.headline4,
                );
              },
            )
          ],
        ),
      ),
      floatingActionButton: MachineConsumer<String, VoidEvent>(
        initial: (_) => const Text(""),
        builder:
            (BuildContext context, String? msg, Handler<VoidEvent> callback) =>
                FloatingActionButton(
          onPressed: () => callback(VoidEvent()),
          tooltip: 'Increment',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
```

[MachineConsumer](https://github.com/simprok-dev/simprokmachine-flutter/wiki/MachineConsumer) - a ```Consumer``` from ```provider``` package with two builders:    
- Initial builder to show UI before first input is received.
- Normal builder to handle input and set up an output callback.


## Step 6 - Code Window
    
```Dart
class Window extends ChildWidgetMachine<String, VoidEvent> {
  @override
  Widget child() {
    return const MyApp();
  }
}
```

[ChildWidgetMachine](https://github.com/simprok-dev/simprokmachine-flutter/wiki/ChildWidgetMachine) - a machine that directs all the input from its parent to the ```MachineConsumer```  inside the widget returned from ```child()``` method. 

 
    
## Step 7 - Code Display 
    
Code ```Display``` class to connect ```Logger``` and ```Window``` together.    


```Dart
class Display extends ParentWidgetMachine<AppEvent, AppEvent> {
  final SharedPreferences _prefs;

  Display(this._prefs);

  @override
  WidgetMachine<AppEvent, AppEvent> child() {
    final WidgetMachine<String, AppEvent> ui = Window()
        .outward((_) => Ward<AppEvent>.single(AppEvent.willChangeState()));

    final Machine<String, AppEvent> logger =
        Logger().outward((void output) => Ward<AppEvent>.ignore());

    final Machine<AppEvent, AppEvent> writer =
        StorageWriter(_prefs).inward((AppEvent event) {
      final int? didChangeState = event.didChangeState;
      if (didChangeState != null) {
        return Ward<int>.single(didChangeState);
      } else {
        return Ward<int>.ignore();
      }
    }).outward((void output) => Ward<AppEvent>.ignore());

    final WidgetMachine<AppEvent, AppEvent> merged = mergeWidgetMachine(
      main: ui,
      secondary: {logger},
    ).inward((AppEvent event) {
      final int? didChangeState = event.didChangeState;
      if (didChangeState != null) {
        return Ward<String>.single("$didChangeState");
      } else {
        return Ward<String>.ignore();
      }
    });

    return mergeWidgetMachine(main: merged, secondary: {writer});
  }
}
```

- [ParentMachine](https://github.com/simprok-dev/simprokmachine-flutter/wiki/ParentMachine) - is an intermediate layer for your data flow. It passes input from the parent to the child and vice versa for the output.
- [ParentWidgetMachine](https://github.com/simprok-dev/simprokmachine-flutter/wiki/ParentWidgetMachine) - the same as ```ParentMachine``` but for ```WidgetMachine```s instead of ```Machine```s.
- [inward()](https://github.com/simprok-dev/simprokmachine-flutter/wiki/Machine#inward-operator) - maps parent input type into child input type or ignores it.
- [outward()](https://github.com/simprok-dev/simprokmachine-flutter/wiki/Machine#outward-operator) - maps child output type into parent output type or ignores it, or sends backs input.
- [merge()](https://github.com/simprok-dev/simprokmachine-flutter/wiki/Global-functions#merge-machines) - merges two or more machines into one.
- [mergeWidgetMachine()](https://github.com/simprok-dev/simprokmachine-flutter/wiki/Global-functions#merge-widget-machines) - merges one ```WidgetMachine``` with one or more ```Machine```s.


    
## Step 8 - Code StorageReader, StorageWriter, and Calculator.

```Dart
class StorageReader extends ChildMachine<VoidEvent, int> {
  final SharedPreferences _prefs;

  StorageReader(this._prefs);

  @override
  void process(VoidEvent? input, Handler<int> callback) {
    callback(_prefs.getInt(storageKey) ?? 0);
  }
}
```


```Dart
class StorageWriter extends ChildMachine<int, void> {
  final SharedPreferences _prefs;

  StorageWriter(this._prefs);

  @override
  void process(int? input, Handler<void> callback) {
    if (input != null) {
      _prefs.setInt(storageKey, input);
    }
  }
}
```


```Dart
class Calculator extends ChildMachine<VoidEvent, int> {
  int _counter;

  Calculator(this._counter);

  @override
  void process(VoidEvent? input, Handler<int> callback) {
    if (input != null) {
      _counter += 1;
    }
    callback(_counter);
  }
}
```

## Step 9 - Code Domain

Code a ```Domain``` class to connect ```StorageReader``` and ```Calculator```.


```Dart
class Domain extends ParentMachine<AppEvent, AppEvent> {
  final SharedPreferences _prefs;

  Domain(this._prefs);

  @override
  Machine<AppEvent, AppEvent> child() {
    Machine<DomainInput, DomainOutput> getCalculator(int value) {
      return Calculator(value).outward((int output) {
        return Ward<DomainOutput>.single(DomainOutput.fromCalculator(output));
      }).inward((DomainInput input) {
        final int? fromReader = input.fromReader;
        if (fromReader != null) {
          return Ward<VoidEvent>.ignore();
        } else {
          return Ward<VoidEvent>.single(VoidEvent());
        }
      });
    }

    final Machine<DomainInput, DomainOutput> reader =
        StorageReader(_prefs).outward((int output) {
      return Ward<DomainOutput>.single(DomainOutput.fromReader(output));
    }).inward((DomainInput input) {
      return Ward<VoidEvent>.ignore();
    });

    final Machine<DomainInput, DomainOutput> connectable =
        ConnectableMachine.create<DomainInput, DomainOutput,
            BasicConnection<DomainInput, DomainOutput>>(
      BasicConnection<DomainInput, DomainOutput>({reader}),
      (BasicConnection<DomainInput, DomainOutput> state, DomainInput input) {
        final int? fromReader = input.fromReader;
        if (fromReader != null) {
          return ConnectionType<DomainInput, DomainOutput,
                  BasicConnection<DomainInput, DomainOutput>>.reduce(
              BasicConnection<DomainInput, DomainOutput>(
                  {getCalculator(fromReader)}));
        } else {
          return ConnectionType<DomainInput, DomainOutput,
              BasicConnection<DomainInput, DomainOutput>>.inward();
        }
      },
    ).redirect((DomainOutput output) {
      if (output.isFromReader) {
        return Direction<DomainInput>.back(
          Ward<DomainInput>.single(
            DomainInput.fromReader(output.value),
          ),
        );
      } else {
        return Direction<DomainInput>.prop();
      }
    });

    return connectable.outward((DomainOutput output) {
      if (output.isFromReader) {
        return Ward<AppEvent>.ignore();
      } else {
        return Ward<AppEvent>.single(AppEvent.didChangeState(output.value));
      }
    }).inward((AppEvent input) {
      final int? didChangeState = input.didChangeState;
      if (didChangeState != null) {
        return Ward<DomainInput>.ignore();
      } else {
        return Ward<DomainInput>.single(DomainInput.fromParent());
      }
    });
  }
}
```

Here we use two helper instances: ```DomainInput``` and ```DomainOutput```.

```Dart
class DomainInput {
  final int? fromReader;

  DomainInput.fromReader(int value) : fromReader = value;

  DomainInput.fromParent() : fromReader = null;
}
```

```Dart
class DomainOutput {
  final bool isFromReader;
  final int value;

  DomainOutput.fromReader(this.value) : isFromReader = true;

  DomainOutput.fromCalculator(this.value) : isFromReader = false;
}
```

[redirect()](https://github.com/simprok-dev/simprokmachine-flutter/wiki/Machine#redirect-operator) - depending on the output either passes it further to the root or sends an array of input data back to the child.
[ConnectableMachine](https://github.com/simprok-dev/simprokmachine-flutter/wiki/ConnectableMachine) - dynamically creates and connects a set of machines.



## Step 10 - Update Display

Add ```StorageWriter``` next to the ```Logger``` and ```Window``` in the ```Display``` class.

```Dart
class Display extends ParentWidgetMachine<AppEvent, AppEvent> {
  final SharedPreferences _prefs;

  Display(this._prefs);

  @override
  WidgetMachine<AppEvent, AppEvent> child() {
    ...

    final Machine<AppEvent, AppEvent> writer =
        StorageWriter(_prefs).inward((AppEvent event) {
      final int? didChangeState = event.didChangeState;
      if (didChangeState != null) {
        return Ward<int>.single(didChangeState);
      } else {
        return Ward<int>.ignore();
      }
    }).outward((void output) => Ward<AppEvent>.ignore());

    final WidgetMachine<AppEvent, AppEvent> merged = ...

    return mergeWidgetMachine(main: merged, secondary: {writer});
  }
}
```

As ```StorageWriter```'s input is ```int``` and not ```String``` we cannot merge it with the other classes. 


We apply ```inward()``` having ```Machine<AppEvent, AppEvent>``` as a result and only then merge it with the others.



## Step 11 - Code main function

```Dart
void main() {
    WidgetsFlutterBinding.ensureInitialized();
    final SharedPreferences prefs = await SharedPreferences.getInstance(); // this is not a good way of doing it. but the sample is about a different thing
    
    runRootMachine<AppEvent, AppEvent>(
        mergeWidgetMachine(
          main: Display(prefs),
          secondary: { Domain(prefs) },
        ).redirect((AppEvent output) => Direction<AppEvent>.back(Ward<AppEvent>.single(output))),
    );
}
```

[runRootMachine<Input, Output>()](https://github.com/simprok-dev/simprokmachine-flutter/wiki/Global-functions#run-root-machine) - starts the flow.



## Step 12 - Enjoy yourself for a couple of minutes

Run the app and see how things are working.


![result](https://github.com/simprok-dev/simprokmachine-flutter/blob/main/sample/images/results.gif)


## To sum up

- ```ChildMachine``` is a container for logic that handles input and may produce an output.  
- ```ChildWidgetMachine``` is a connector of the input and output flows to your flutter widgets.    
- ```MachineConsumer``` is a ```Consumer``` from ```provider``` package that receives input, output callback and applies it onto UI.    
- ```ParentMachine``` and ```ParentWidgetMachine``` are proxy/intermediate classes used for comfortable logic separation and as a place to apply operators.
- ```inward()``` is an operator to map the parent's input type into the child's input type or ignore it.
- ```outward()``` is an operator to map the child's output type into the parent's output type or ignore it.
- ```redirect()``` is an operator to either pass the output further to the root or map it into an array of inputs and send back to the child.
- ```merge()``` and ```mergeWidgetMachine()``` are operators to merge two or more machines of the same input and output types.
- ```ConnectableMachine``` is a machine that is used to dynamically create and connect other machines.
- ```runRootMachine<Input, Output>()``` is a function that starts the flow of the app.

Refer to [wiki](https://github.com/simprok-dev/simprokmachine-flutter/wiki) for more information.
