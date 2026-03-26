#pragma once

#include <ida.hpp>
#include <bytes.hpp>

// IDA 9.2 moved the ignore-micro helpers onto ignore_micro_t.
// Older SDKs expose the same behavior via global helpers backed by netnode.
#if IDA_SDK_VERSION >= 920
using idaxex_ignore_micro_t = ignore_micro_t;

inline void idaxex_init_ignore_micro(idaxex_ignore_micro_t& state)
{
  state.init_ignore_micro();
}

inline void idaxex_mark_prolog(idaxex_ignore_micro_t& state, ea_t ea)
{
  state.mark_prolog_insn(ea);
}

inline void idaxex_mark_epilog(idaxex_ignore_micro_t& state, ea_t ea)
{
  state.mark_epilog_insn(ea);
}
#else
using idaxex_ignore_micro_t = netnode;

inline void idaxex_init_ignore_micro(idaxex_ignore_micro_t&)
{
  init_ignore_micro();
}

inline void idaxex_mark_prolog(idaxex_ignore_micro_t&, ea_t ea)
{
  mark_prolog_insn(ea);
}

inline void idaxex_mark_epilog(idaxex_ignore_micro_t&, ea_t ea)
{
  mark_epilog_insn(ea);
}
#endif
