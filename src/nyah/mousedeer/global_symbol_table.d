module mousedeer.global_symbol_table;

import mousedeer.parser.nyah
  : Function, VariableDefinition, Class, Global, GlobalNamespace, Module;
import mousedeer.function_overloads : FunctionOverloads;
import mousedeer.identifiable : Identifiable;
import mousedeer.object_module : ObjectModule;
import mousedeer.source_file : SourceFile;

import teg.range : Range;

import beard.vector : pushBack;

class ExceptionWithLocation : Exception {
  this(Range loc, string msg) {
    loc_ = loc;
    super(msg);
  }

  // todo: override toString to give location better

  private Range loc_;
}

class SymbolRedefinition : ExceptionWithLocation {
  this(Range fromId, Range toId_, string msg) {
    super(fromId, msg);
    toId = toId_;
  }

  Range fromId() { return loc_; }
  Range toId;
}

// Builds global symbol table from parsed AST. The algorithms used rely on
// the source files being processed one after the other. The symbol table
// builder acts as the target of variant apply methods called on each AST
// in term, implementing a generic visitor pattern.
struct SymbolTableBuilder {
 private:
  Global.NamespacePtr parent_;     // parent of current global objects
  ObjectModule        objModule_;  // current object module
  SourceFile          sourceFile_; // current source file
  // set if the current source file has global module contents
  bool                sourceHasGlobal_;

  // While building the symbol table the builder keeps a list of all
  // the function overloads it meets for processing in a pass after
  // the symbol table is built.
  FunctionOverloads[] overloads_;

  void childOfGlobal(T)(auto ref T v) {
    if (! sourceHasGlobal_) {
      objModule_ = new ObjectModule(sourceFile_.pathFromRoot ~ "/global.bc");
      sourceHasGlobal_ = true;
    }
    opCall(v);
  }

 public:
  // Record a new global symbol in the current namespace parent_
  void newSymbol(T)(Range id, auto ref T v) {
    auto namespace = parent_.base!GlobalNamespace;
    auto idStr = id.str;

    auto ptr = idStr in namespace.symbols_;
    if (ptr) {
      static if (is(T : Function)) {
        if (ptr.isType!Function) {
          auto overloads = new FunctionOverloads(ptr.as!Function);
          pushBack(overloads_, overloads);
          namespace.symbols_[idStr] = overloads;
          overloads.addFunction(v);
        }
        else if (ptr.isType!FunctionOverloads)
          ptr.as!FunctionOverloads.addFunction(v);
        else
          throw new SymbolRedefinition(
            id, ptr.base!Identifiable.id, "redefined as function");

        return;
      }
      else static if (is(T : VariableDefinition)) {
        if (! ptr.isType!VariableDefinition)
          throw new SymbolRedefinition(
            id, ptr.base!Identifiable.id, "redefined as variable definition");
        else
          throw new SymbolRedefinition(
            id, ptr.base!Identifiable.id, "duplicate variable definition");
      }
      else static if (is(T : Class)) {
        if (! ptr.isType!Class)
          throw new SymbolRedefinition(
            id, ptr.base!Identifiable.id, "redefined as class");
        else
          throw new SymbolRedefinition(
            id, ptr.base!Identifiable.id, "duplicate class");
      }
      else static if (is(T : Module)) {
        if (! ptr.isType!Module)
          throw new SymbolRedefinition(
            id, ptr.base!Identifiable.id, "redefined as module");
        else
          return; // allow modules to be defined in multiple places
      }
      else assert(false, "unreachable");
    }
    namespace.symbols_[idStr] = v;
  }

  void opCall(T)(auto ref T v) {
    GlobalNamespace namespace = parent_.base!GlobalNamespace;
    static if (is(T : Module)) {
      auto bcPath = "/" ~ v.ids()[0].str;
      foreach (id ; v.ids()[1..$]) bcPath ~= "." ~ id.str;
      bcPath ~= ".bc";

      objModule_ = new ObjectModule(sourceFile_.pathFromRoot ~ bcPath);
      v.setObjectModule(objModule_);

      auto parentBak = parent_;

      for (auto i = 0; i < v.ids.length; ++i) {
        auto id = v.ids[i];
        auto ptr = id.str in namespace.symbols_;
        if (ptr) {
          if (! ptr.isType!Module) {
            throw new SymbolRedefinition(
              id, ptr.base!Identifiable.id, "redefined as module");
          }
          namespace = ptr.as!Module;
          // TODO: append members if module?
        }
        else if (i == v.ids.length - 1) {
          // first time module is seen
          newSymbol(id, v);
          namespace = v;
        }
        else {
          // empty module created to be parent of current module
          auto newNamespace = new Module;
          newNamespace.ids = v.ids[0..(i+1)];
          newSymbol(id, newNamespace);
          namespace = newNamespace;
        }

        namespace.parent = parent_;
        parent_ = cast(Module)namespace;
      }

      foreach (node ; v.members)
        node.apply(this);

      parent_    = parentBak;
      return;
    }
    else static if (is(T : Global)) {
      v.parent = parent_;
      v.setObjectModule(objModule_);
      newSymbol(v.id, v);
    }

    static if (is(T : Class)) {
      auto parentBak    = parent_;
      namespace = v;
      parent_ = v;

      foreach (node ; v.block.value_)
        node.apply(this);

      parent_ = parentBak;
    }
  }

  void empty() { assert(false, "cannot be empty"); }

  // Import an AST from file into the symbol table of module_. This also
  // sets the parents and object module references within all global ast nodes.
  void import_(Module module_, SourceFile file) {
    parent_          = module_;
    sourceFile_      = file;
    sourceHasGlobal_ = false;

    foreach (node ; file.ast)
      node.apply(
          (Class v) { childOfGlobal(v); },
          (VariableDefinition v) { childOfGlobal(v); },
          (Function v) { childOfGlobal(v); },
          this); // intercept global non-modules specially
  }

  // This must be called after importing all source files in order to build
  // the function overload tables. This process will need access to all global
  // symbols in order to build overloads reliant on metaprogramming.
  void buildOverloadTables() {
    foreach(FunctionOverloads overloads; overloads_)
      overloads.buildLookupTree;
  }
}

class GlobalSymbolTable : Module {};
// vim:ts=2 sw=2:
