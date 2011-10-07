module teg.node;

import teg.detail.parser : hasSubparser, storingParser;
import beard.io;

template makeNode(P...) {
    alias void __IsNode;

    mixin hasSubparser!P;
    mixin storingParser;

    static bool skip(S, O)(S s, ref O o) {
        return subparser.skip(s, o.value_);
    }

    void printTo(S)(int indent, S stream) {
        stream.write(typeid(this).name, " {\n");
        printIndent(stream, indent + 1);
        printIndented(stream, indent + 1, value_);
        stream.write('\n');
        printIndent(stream, indent);
        print('}');
    }

    stores!subparser value_;
}

template isNode(T) {
    enum isNode = is(T.__IsNode);
}
