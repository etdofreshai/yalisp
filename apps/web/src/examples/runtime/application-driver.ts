// The explicit extension keeps this module loadable by Node's type stripping,
// so the same driver runs in a browser, in tests, and in benchmarks.
import { atomText, directive, directives, parseLispValue, printLispValue, type LispValue } from "./lisp-value.ts";

// The generic tick driver for YALISP applications. It owns no game behavior:
// it only decides how a program's state crosses the host boundary, and it is
// intentionally free of DOM and seed imports so a browser host, a Node test,
// and a benchmark can drive identical ticks.
//
// Two contracts are supported.
//
//   printed state (original)
//     (app.initial-state)            -> the starting state value
//     (app.frame state input)        -> ((state next) directives...)
//   The host prints the whole state into the next call and parses the whole
//   state back out of every result, so per-tick cost grows with state size.
//
//   resident state handle (opt-in, detected with (bound? 'app.attach))
//     (app.attach)                   -> install the program's own state
//     (app.advance input)            -> advance that state by one tick
//     (app.present)                  -> directives for the current state
//     (app.state)                    -> optional; the state value, for replay
//   The state never leaves the evaluator. A tick transfers only the input
//   form and produces no output at all, so its cost is independent of how
//   large the program's state has grown. This is what makes a 320x200
//   simulation viable; nothing here assumes what that simulation is.

export interface DriverSession {
  evaluate(source: string): string;
  evaluateQuietly(source: string): void;
}

export type ApplicationMode = "printed-state" | "state-handle";

export interface ApplicationDriver {
  readonly mode: ApplicationMode;
  attach(): void;
  tick(inputForm: string): { resultRequested: boolean };
  present(): LispValue;
  stateText(): string;
}

function bound(session: DriverSession, name: string) {
  return session.evaluate(`(bound? '${name})`) === "true";
}

export function createApplicationDriver(session: DriverSession): ApplicationDriver {
  if (!bound(session, "app.attach")) return printedStateDriver(session);
  for (const name of ["app.advance", "app.present"]) {
    if (!bound(session, name)) {
      throw new Error(`A Lisp application that defines app.attach must also define ${name}.`);
    }
  }
  return stateHandleDriver(session);
}

function printedStateDriver(session: DriverSession): ApplicationDriver {
  let state: LispValue = [];
  let latest: LispValue | undefined;
  return {
    mode: "printed-state",
    attach() {
      state = parseLispValue(session.evaluate("(app.initial-state)"));
      latest = undefined;
    },
    tick(inputForm) {
      const result = parseLispValue(session.evaluate(`(app.frame '${printLispValue(state)} '${inputForm})`));
      const values = directives(result);
      const next = directive(values, "state");
      if (!next?.[1]) throw new Error("The Lisp application did not return its next state.");
      state = next[1];
      // The transported state is transport, not a directive: dropping it here
      // makes both contracts present the same list to the same renderer.
      latest = values.filter((value) => atomText(value[0] ?? "") !== "state");
      return { resultRequested: Boolean(directive(values, "result")) };
    },
    present() {
      return latest ?? parseLispValue(session.evaluate(`(app.view '${printLispValue(state)})`));
    },
    stateText() {
      return printLispValue(state);
    }
  };
}

function stateHandleDriver(session: DriverSession): ApplicationDriver {
  const exposesState = bound(session, "app.state");
  return {
    mode: "state-handle",
    attach() {
      session.evaluateQuietly("(app.attach)");
    },
    tick(inputForm) {
      // No printing, no parsing, no state round trip: the evaluator keeps the
      // state and the host hands it only this tick's input.
      session.evaluateQuietly(`(app.advance '${inputForm})`);
      return { resultRequested: false };
    },
    present() {
      return parseLispValue(session.evaluate("(app.present)"));
    },
    stateText() {
      return exposesState ? session.evaluate("(app.state)") : "";
    }
  };
}
