/**
 * Provides a taint-tracking configuration for reasoning about hard-coded data
 * being interpreted as code.
 */

import javascript
private import semmle.javascript.security.dataflow.CodeInjection

module HardcodedDataInterpretedAsCode {
  /**
   * A data flow source for hard-coded data.
   */
  abstract class Source extends DataFlow::Node {
    /** Gets a flow label for which this is a source. */
    DataFlow::FlowLabel getLabel() {
      result = DataFlow::FlowLabel::data()
    }
  }

  /**
   * A data flow sink for code injection.
   */
  abstract class Sink extends DataFlow::Node {
    /** Gets a flow label for which this is a sink. */
    abstract DataFlow::FlowLabel getLabel();

    /** Gets a description of what kind of sink this is. */
    abstract string getKind();
  }

  /**
   * A sanitizer for hard-coded data.
   */
  abstract class Sanitizer extends DataFlow::Node {}

  /**
   * A taint-tracking configuration for reasoning about hard-coded data
   * being interpreted as code
   */
  class Configuration extends TaintTracking::Configuration {
    Configuration() {
      this = "HardcodedDataInterpretedAsCode"
    }
  
    override predicate isSource(DataFlow::Node source, DataFlow::FlowLabel lbl) {
      source.(Source).getLabel() = lbl
    }
  
    override predicate isSink(DataFlow::Node nd, DataFlow::FlowLabel lbl) {
      nd.(Sink).getLabel() = lbl
    }

    override predicate isSanitizer(DataFlow::Node node) {
      node instanceof Sanitizer
    }
  }

  /**
   * A constant string consisting of eight or more hexadecimal characters (including at
   * least one digit), viewed as a source of hard-coded data that should not be
   * interpreted as code.
   */
  private class DefaultSource extends Source, DataFlow::ValueNode {
    DefaultSource() {
      exists (string val | val = astNode.(Expr).getStringValue() |
        val.regexpMatch("[0-9a-fA-F]{8,}") and
        val.regexpMatch(".*[0-9].*")
      )
    }
  }

  /**
   * A code injection sink; hard-coded data should not flow here.
   */
  private class DefaultCodeInjectionSink extends Sink {
    DefaultCodeInjectionSink() { this instanceof CodeInjection::Sink }
    override DataFlow::FlowLabel getLabel() { result = DataFlow::FlowLabel::taint() }
    override string getKind() { result = "code" }
  }

  /**
   * An argument to `require` path; hard-coded data should not flow here.
   */
  private class RequireArgumentSink extends Sink {
    RequireArgumentSink() {
      this = any(Require r).getAnArgument().flow()
    }

    override DataFlow::FlowLabel getLabel() {
      result = DataFlow::FlowLabel::data()
      or
      result = DataFlow::FlowLabel::taint()
    }

    override string getKind() { result = "an import path" }
  }
}
