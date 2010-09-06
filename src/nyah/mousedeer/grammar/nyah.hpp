#ifndef NYAH_MOUSEDEER_GRAMMAR_NYAH_HPP
#define NYAH_MOUSEDEER_GRAMMAR_NYAH_HPP

#include <nyah/mousedeer/grammar/grammar.hpp>

namespace nyah { namespace mousedeer { namespace grammar { namespace nyah {

using namespace chilon::parser;
using namespace chilon::parser::ascii;

using grammar::Spacing;

typedef lexeme<
    choice<char_<'_'>, char_range<a,z, A,Z> >,
    many< choice<
        char_range<a,z, A,Z, '0','9'>,
        char_from<'_','.'>
    > > > MetaIdentifier;

struct MetaGrammar : simple_node<MetaGrammar,
    sequence<
        char_<'@',g,r,a,m,m,a,r>, MetaIdentifier,
        optional<
            char_<'@',e,x,t,e,n,d,s>, MetaIdentifier>,
        grammar::Grammar> > {};

typedef many<MetaGrammar> Grammar;

} } } }
#endif