# date: a calendar library for Vox, and textkit 0.2

Status: design, 2026-09-27. Two libraries in one plan because they ship
together in the next vox-libs release; they are otherwise independent.

## Why

Vox gives a program the current time and its parts, and nothing else about
the calendar: no way to say "the Wednesday after the first of next month",
no way to print `29 Jul 2026`, no way to read a date typed on a command
line. Every program that needs any of that hand-rolls month tables and leap
year rules, and gets some of it wrong.

GNU `date` is the reference for what a general date tool does: take a
moment, describe it in any layout, read one back from text, and move it
around the calendar. This library is that feature set for a Vox program,
under the C locale (English names, UTC), which is the only locale Vox has.

The scheduler that motivated this is one consumer among many and gets no
special treatment. Nothing in here knows about meetings.

## What is out of scope

- Setting the system clock (`date -s`). A library does not administer the
  machine.
- Time zones other than UTC. Vox's own `time` is UTC (verified: `now's hour`
  reads 16 while the machine's local clock reads 17 BST). A parsed offset
  such as `+01:00` is honoured on the way in, and output is always UTC with
  `%z` = `+0000` and `%Z` = `UTC`. Zone rules are a later library.
- Sub-second precision (`%N`, `--resolution`). Vox's clock is whole seconds.
- Locale variants (`%E`, `%O` modifiers, `%c`/`%x`/`%X` in anything but the
  C locale layout).

## The representation: a moment

A **moment** is a `number`: whole seconds since 1970-01-01 00:00:00 UTC.
It is the same number Vox's `time` hands out as `now's unix`, the same
number GNU prints for `%s` and reads for `@N`, and it fits any number slot,
which matters because a `.lib` interface cannot carry a user-defined thing.

A date with no time of day is the moment at midnight. Moments before 1970
are negative and work throughout (proleptic Gregorian, as GNU does). Vox's
`divide` and `modulo` truncate toward zero, so every conversion floors
explicitly rather than trusting them on a negative moment.

## Exports

Every export is a function whose name reads at the call site. A number that
stands for a moment is called `moment` in a signature; a number that stands
for a count is called what it counts. Reserved words the author will hit
and must quote or avoid: `when`, `second`, `seconds`, `day`, `days`,
`hour`, `hours`, `minute`, `minutes`, `month`, `months`, `year`, `years`,
`unix`, `timestamp`, `current`, `count` is fine.

### Now

| Call | Returns |
|---|---|
| `'the moment now'` | the current moment |

### Civil time to a moment

| Call | Returns |
|---|---|
| `'the moment of' with year and month and 'day of month'` | midnight of that date |
| `'the moment at' with year and month and 'day of month' and hour and minute and second` | that clock time |

Fields that overflow normalise the way C's `mktime` does: day 0 is the last
day of the previous month, day 32 of January is 1 February, month 13 is
January of the next year, hour 24 is midnight tomorrow. This is deliberate,
because it is what makes "the date seven days on" a one-liner in a caller
that keeps its own year, month and day.

### A moment to its parts

All take one number, a moment, and return a number.

| Call | Returns | GNU |
|---|---|---|
| `'the year of'` | e.g. 2026 | `%Y` |
| `'the month of'` | 1..12 | `%m` |
| `'the day of month of'` | 1..31 | `%d` |
| `'the hour of'` | 0..23 | `%H` |
| `'the minute of'` | 0..59 | `%M` |
| `'the second of'` | 0..59 | `%S` |
| `'the weekday of'` | 1 Monday .. 7 Sunday | `%u` |
| `'the day of year of'` | 1..366 | `%j` |
| `'the iso week of'` | 1..53 | `%V` |
| `'the iso week year of'` | the year that ISO week belongs to | `%G` |
| `'the quarter of'` | 1..4 | `%q` |
| `'the century of'` | e.g. 20 | `%C` |

### Names

| Call | Example |
|---|---|
| `'the month name of' of month` | "July" |
| `'the short month name of' of month` | "Jul" |
| `'the weekday name of' of weekday` | "Wednesday" |
| `'the short weekday name of' of weekday` | "Wed" |

An argument outside 1..12 or 1..7 yields the empty text.

### Calendar facts

| Call | Returns |
|---|---|
| `'is a leap year' of year` | boolean |
| `'the days in' of month and year` | 28..31 |
| `'is a valid date' of year and month and 'day of month'` | boolean; the strict check that `'the moment of'` deliberately does not make |
| `'is a valid time' of hour and minute and second` | boolean |

### Moving around the calendar

All take a moment and a signed count, and return a moment. A negative count
goes backwards.

| Call | Notes |
|---|---|
| `'seconds later' of moment and count` | |
| `'minutes later' of moment and count` | |
| `'hours later' of moment and count` | |
| `'days later' of moment and count` | |
| `'weeks later' of moment and count` | |
| `'months later' of moment and count` | the day of month is **clamped** to the target month: 31 January plus one month is 28 (or 29) February. GNU overflows into March instead; clamping is what a person asking for "a month later" means, and the difference is documented in the README. |
| `'years later' of moment and count` | 29 February plus one year is 28 February, by the same clamping |

Anchors, each taking a moment and returning a moment:

| Call | Returns |
|---|---|
| `'the start of the day of'` | midnight |
| `'the start of the week of'` | midnight on the Monday on or before |
| `'the start of the month of'` | midnight on the 1st |
| `'the start of the year of'` | midnight on 1 January |
| `'the weekday on or after' of moment and weekday` | midnight of the first such weekday, the same day if it already is one |
| `'the weekday on or before' of moment and weekday` | likewise, backwards |

And one difference: `'the days between' of 'the earlier' and 'the later'`
returns whole days, floored, negative when the second is earlier.

### Writing a moment out

| Call | Layout | GNU |
|---|---|---|
| `'the moment written as' of moment and layout` | any layout below | `+FORMAT` |
| `'the date of'` | `2026-07-29` | `-I` |
| `'the date and time of'` | `2026-07-29T16:02:48+00:00` | `-Iseconds` |
| `'the rfc 3339 date and time of'` | `2026-07-29 16:02:48+00:00` | `--rfc-3339=seconds` |
| `'the rfc email date of'` | `Wed, 29 Jul 2026 16:02:48 +0000` | `-R` |
| `'the moment in words of'` | `Wed Jul 29 16:02:48 UTC 2026` | bare `date` |

The layout language is GNU's. Every one of these sequences is honoured with
the meaning `date --help` gives it, in the C locale: `%%` `%a` `%A` `%b`
`%B` `%c` `%C` `%d` `%D` `%e` `%F` `%g` `%G` `%h` `%H` `%I` `%j` `%k` `%l`
`%m` `%M` `%n` `%p` `%P` `%q` `%r` `%R` `%s` `%S` `%t` `%T` `%u` `%U` `%V`
`%w` `%W` `%x` `%X` `%y` `%Y` `%z` `%Z`. The padding flags `-` (no
padding), `_` (spaces), `0` (zeros), `^` (upper case) and `#` (swap case)
are honoured, and so is an optional field width after them, exactly as
GNU's rule reads: flags first, then width. `%z` is always `+0000` and `%Z`
always `UTC`. A `%` followed by anything else is copied through unchanged,
which is what GNU does.

### Reading a moment in

| Call | Returns |
|---|---|
| `'the moment read from' of text` | the moment, or 0 when the text is not one |
| `'reads as a moment' of text` | whether the text is one |

Two calls because a library cannot raise Vox's error flag across the `.so`
boundary (the same reason json ships `'reads as json'`), and 0 is a real
moment.

Accepted, after trimming and case-insensitively where letters appear:

- `2026-07-29`, `2026-07-29 16:02:48`, `2026-07-29T16:02:48`, each with
  an optional `Z`, `+hh:mm`, `+hhmm` or `+hh` offset, which is applied so
  the result is UTC
- `20260729` and `20260729T160248`
- `@1790525009` (seconds since the epoch, signed)
- `29 Jul 2026`, `29 July 2026`, `Jul 29 2026`, `July 29, 2026`, each with
  an optional trailing `16:02:48` or `16:02`

Anything else is not a moment. A date that does not exist (`2026-02-30`)
is refused, not normalised: reading is strict where `'the moment of'` is
forgiving, because typed input is where mistakes come from.

### Relative descriptions

The half of `date -d` people actually use:

| Call | Returns |
|---|---|
| `'the moment described by' of text and 'the moment it is relative to'` | the moment, or 0 |
| `'reads as a description' of text` | whether the text is one |

A description is an optional absolute moment (any form above) followed by
zero or more relative items, in either order for the items, separated by
spaces. When no absolute moment is given, the items apply to the second
argument, which a caller usually passes as `'the moment now'`.

Relative items, matching GNU's meaning:

- `now`, `today` (start of the day), `tomorrow`, `yesterday`
- `N days`, `N weeks`, `N months`, `N years`, `N hours`, `N minutes`,
  `N seconds`, singular or plural, with an optional leading `+` or `-`, and
  the word `ago` after any of them negating it
- `next <unit>` and `last <unit>` for the same units, meaning `1 <unit>` and
  `-1 <unit>`
- a weekday name, full or short (`wednesday`, `wed`): the first such day on
  or after the base date, at midnight, as GNU reads a bare weekday
- `next <weekday>`: the first such day strictly after the base date, and
  `last <weekday>` the first strictly before, both at midnight

So `'the moment described by' of "next wednesday" and 'the moment now'`,
`"2026-07-29 + 7 days"`, `"3 weeks ago"` and `"tomorrow 2 hours"` all read
as GNU reads them.

## Tests

`date/date_tests.vox` follows the json library's pattern: named claims, a
tally, exit 1 on any failure, and an expected transcript that is only the
headings and the tally. Every expected value that GNU can produce is taken
from GNU: the author runs `date -u -d '...' '+...'` while writing the test
and records the literal answer beside the command as a comment, so the
tests are a fidelity check against the reference and not against the
author's own reading of it. The suite covers at least:

- every specifier in the layout list, on one fixed moment, and each flag
- the epoch, the day before the epoch, a leap day, 31 December, 1 January,
  the ISO week edge cases (a 1 January that belongs to the previous year's
  week 52 or 53, a 31 December that belongs to week 1 of the next year)
- every parse form above, each with one accepted and one refused example
- every relative item, including `ago` and the weekday forms on a base date
  that is itself that weekday
- round trips: written out and read back is the same moment

`date/date_demo.vox` is the readable tour: one realistic use of each group
above, with its `.expected` transcript.

## Files and build

- `date/date.vox` with `Library date version "0.1".` on its first line
- `date/date_demo.vox`, `date/date_demo.expected`
- `date/date_tests.vox`, `date/date_tests.expected`
- `Makefile`: `date` added to `LIBS`
- `README.md`: a row in the library table and a paragraph on the moment
  representation and the two documented departures from GNU (clamped month
  arithmetic, UTC only)
- `CHANGELOG.md`: under a new `[0.3.0]` heading
- `vox-libs.spec`: description mentions date

## Implementation notes for the author

- Days from civil and civil from days: Howard Hinnant's algorithms
  (`days_from_civil` / `civil_from_days`), which are exact for the
  proleptic Gregorian calendar and need only integer arithmetic. Floor the
  divisions by hand; Vox truncates.
- 1 January 1970 was a Thursday, so the weekday in the 1..7 Monday form is
  `((days add 3) modulo 7) add 1` once the modulo is made non-negative.
- The layout writer walks the layout byte by byte into one dynamic buffer
  and returns `"{output}"`. Each specifier is one small function so the
  table above is also the table of contents of the source.
- A text literal inside a format hole is a parse error in vox 0.4.15
  (`"{f of "x"}"`), so hoist the literal into a named variable first.
- Follow `docs/STYLE.md` in the Vox repo: every line reads aloud, names are
  the thing's true name, booleans are conditions, comments say why.

---

# textkit 0.2

textkit splits only on whitespace, which is right for words and wrong for
everything delimited: a CSV row, a `PATH`, a `key=value` line. Three
additions make it a general tokenizer.

| Call | Returns |
|---|---|
| `'split on' of text and separator` | the fields between each occurrence of `separator`, in order, as a list of text. Empty fields are kept: `"a,,b"` splits on `","` into `["a", "", "b"]`, and a trailing separator yields a trailing empty field. The empty text splits into `[""]`. An empty separator does not split: the result is the whole text as one element. The separator may be more than one byte. |
| `'split lines' of text` | one element per line, on `\n`, with a preceding `\r` dropped so Windows line endings read the same. A trailing newline does not produce a trailing empty element. The empty text yields `[]`. |
| `replace of text and needle and replacement` | every non-overlapping occurrence of `needle` replaced, scanning left to right. An empty needle returns the text unchanged. |

`join` already exists and is the inverse of `'split on'`; the tests say so
with a round trip.

The `Library` line becomes `version "0.2"`. A consumer changes the version
in its one `see` line; the 0.1 functions are unchanged in name and
behaviour. (The language's multi-version `.so` build can carry a frozen
0.1 beside 0.2 if a public consumer ever needs it; nothing on this machine
consumes the installed 0.1, so it is not done now.)

Files: `textkit/textkit.vox`, `textkit/textkit_demo.vox` and its
`.expected` extended with the three new exports at their edges, and a new
`textkit/textkit_tests.vox` in the json pattern. `README.md` row and
`CHANGELOG.md` entry under the same `[0.3.0]` heading.
