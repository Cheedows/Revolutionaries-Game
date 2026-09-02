---
name: lcs-voice
description: >
  The house voice for every word a player reads in Revolutionaries — the deadpan
  wire-service register Liberal Crime Squad is written in, derived from the
  10,760 strings in src/. Use this skill BEFORE writing or rewording any
  player-facing text in this repository: event lines, combat and chase results,
  news stories, headlines, dialogue, interrogation and date scenes, item and
  augmentation descriptions, activity names, menu labels, panel headings,
  tooltips, refusal messages, death lines, endings. Also use it when reviewing
  or editing existing text, when a string fails tools/audit_voice.py, when
  deciding whether a new line needs an exception entry, and whenever a request
  sounds like "write flavour text", "describe this", "what should this say",
  "make this less bland", or "that reads like AI wrote it". Prose in this game
  is content, not presentation — getting it wrong is a parity departure.
---

# The voice of Liberal Crime Squad

## Before you write anything

The original almost certainly already has words for it. `tools/audit_voice.py`
is a CI gate: every string in `game/ui/` must be found in the original's own
source (`src/`) or content (`art/*.xml`), or be listed in
`tools/voice_exceptions.json` with a reason saying what the original does
instead. `tools/voice_backlog.json` is empty and stays empty.

So the first move is never to write. It is to look:

```bash
# what does the original say about this?
python3 .claude/skills/lcs-voice/scripts/find_original.py "flag burning"

# would this draft line pass the audit as carried?
python3 .claude/skills/lcs-voice/scripts/find_original.py --check "%s crawls off moaning..."

python3 tools/audit_voice.py          # after any change to game/ui/
```

`find_original.py` searches the same haystack the audit uses — every string in
`src/` plus every text node in `art/*.xml` — and prints the file and line of
each hit, because the rest of the passage is usually in the next few lines.

Carry what you find, verbatim, including its capitalisation and its two spaces
after the full stop. Write new prose only where the original genuinely printed
nothing — and then write it in the voice below and add the exception entry
explaining what the original does instead.

## What the voice actually is

**A wire report filed by someone who has stopped being surprised.** Tarn Adams
wrote a game about political violence in the register of a local newspaper's
metro desk. Nothing is heightened. Nothing is explained. The horror and the
comedy both come from a flat sentence declining to react.

> A doctor that routinely performed illegal abortion-murders was ruthlessly
> gunned down outside of the Halvorsen Clinic yesterday. Dr. Mia Reyes was
> walking to her car when, according to police reports, shots were fired from
> a nearby vehicle. Reyes was hit 9 times and died immediately in the parking
> lot.

Read that again and notice what is doing the work. Not adjectives — **state**.
The only difference between "illegal abortion-murders" and "abortions" is
`law[LAW_ABORTION]`. The prose is the same; the country changed underneath it.
That is the game's central literary device, and if you take one thing from this
skill, take that one:

**The politics live in the vocabulary the world selects, not in anything the
narrator says.** Never editorialise. Choose the word the current regime would
choose, and let the player notice.

## The seven rules that produce the sound

### 1. Write fragments that begin with a lowercase verb

706 strings in the original are a leading space and a present-tense verb,
because the engine prints a name and then the fragment:

```
" crawls off moaning..."        " smashes one of them in the jaw!"
" runs away screaming!"         " is held down and kicked by three guys!"
" wears a look of pain."        "'s teeth have been smashed out on the curb."
```

Third person, present tense, name first, no pronoun for the actor. This is a
formal constraint from the engine, and it is most of the rhythm. When the port
composes a line, keep the shape: `"%s crawls off moaning."`, not `"They crawl
off, moaning to themselves."`

### 2. Seven words

Median prose string: **7 words.** 90th percentile: **12.** Action lines run
three to eight and take an exclamation mark about a third of the time. Only
news stories are long-form, and they are long because they are made of many
short sentences, not long ones.

If a line has a subordinate clause, ask whether the original would have made it
two lines or one line and a shrug.

### 3. Use almost no punctuation

Across 3,474 prose strings the original uses:

| mark | count | verdict |
|---|---|---|
| `!` | 339 | free — action, alarm, cruelty |
| `?` | 130 | free — dialogue and prompts |
| `...` | 84 | free — dying, trailing off, dawning realisation |
| `;` | 4 | three are inside quotations from Thoreau, King and Zinn |
| `--` / `—` | **2** | effectively never |

An em dash is the loudest tell that a machine wrote a line. So is a semicolon.
So is a colon inside a sentence. Full stop, comma, exclamation mark, ellipsis,
question mark. That is the whole kit.

News prose separates sentences with **two spaces**. Keep them.

### 4. Concrete, banal, specific

"hit 9 times", "Over thirty companies set up booths", "($250)", "three months
from now", "a hot dog cart", "the parking lot". The texture is administrative
detail. Nobody's eyes flash. Nothing is palpable. Weather is not a metaphor.

Names are **generated, never chosen** — the original builds `Dr. <first>
<last>` from its name tables so no NPC is ever authored for significance. If
you need a person in a story, take a name from the generator, not from your
imagination.

### 5. Deadpan the cruelty

```
" crumples under a flurry of blows!"
"'s teeth have been smashed out on the curb."
" sweats profusely, murmurs something about Jesus, and dies."
" silently drifts away, and is gone."
```

No comment, no wink, no softening. The game is playable *because* it never
tells you what to think about what you just did. A line that signals the
author's discomfort breaks it as badly as a line that gloats.

### 6. Speak the game's own dialect

Fixed in-fiction vocabulary. Do not paraphrase these and do not invent
neighbours for them casually:

**Liberal** / **Conservative** (capitalised, factional nouns, not adjectives of
opinion) · **Elite Liberal** · **Automaton** (a captured Conservative) ·
**Enlightened** (converted) · **Juice** (standing) · **Martyr** (dead member) ·
**the Squad** · **Not a Liberal Act** · **the Conservative Crime Squad / CCS** ·
**sleeper** · **safehouse** · **the Liberal Guardian**.

Menu and label register is Title Case with a key letter: `R - Remove member`,
`W - Wait a day`, `PATRIOTISM: fly a flag here ($20)`. Screens shout their
column headers: `CODE NAME`, `SKILL`, `HEALTH`, `LOCATION`, `DAYS IN
CAPTIVITY`. Keep both conventions.

Second person is for the player being instructed or besieged ("You have
received advance warning from your sleepers"). Squad members are always third
person by name. Never "your squad member"; use their name.

### 7. Let the law change the words

Free-speech law rewrites profanity in three tiers, in the text itself:

| `LAW_FREESPEECH` | printed |
|---|---|
| Elite Liberal | `goddamn` · `pissing out the window` |
| Moderate | `g*dd*mn` |
| Arch-Conservative | `[gosh darn]` · `[relieving themselves] out the window` |

The square brackets are **visible to the player**. A censored country prints
`A student has gone on a [hurting spree]`, `[take] the president [on vacation]`,
`throwing [juice boxes]`. It is simultaneously the funniest and the bleakest
thing in the game. When you write a line that could be censored, write both
versions and let the law pick.

Other laws do the same to nouns: abortion becomes "abortion-murder", flag
burning becomes "Flag Murder", a worker becomes an "illegal alien". Look for
the seam and put the state on it.

## The anti-slop pass

Model prose has a signature. Read your draft back hunting for it, because none
of this appears in the original:

- **Em dashes and semicolons.** Two and four respectively, out of ten thousand
  strings. If you have one, you are not writing this game.
- **"Not just X, but Y."** Absent. So is "isn't merely", "more than just".
- **Tricolons.** "cold, tired, and afraid." The original does not balance.
- **Abstract subjects.** "The tension was palpable." "A sense of unease settled
  over the room." Things happen to people with names, in places, at times.
- **Vocabulary that arrived after 2004:** delve, tapestry, testament, stark
  reminder, underscores, highlights, navigate, landscape, resonate, grapple
  with, speaks volumes, a masterclass in, the weight of.
- **The summarising last sentence.** "It was a night nobody would forget." The
  original stops when the facts stop.
- **Explaining the joke.** If the line contains its own punchline and then a
  gloss, cut the gloss.
- **Hedging.** "seemed to", "somewhat", "perhaps", "a bit of a". The metro desk
  reports what happened.
- **Rhetorical questions at the player.** "But at what cost?"
- **Sonorous rhythm.** If it scans like the close of a book blurb, rewrite it as
  a police log entry.

### The drill

**Slop.** *The squad melts into the night, leaving behind a scene of chaos — a
stark reminder that no one is safe.*
**Voice.** *The squad slips out. Sirens start up four blocks away.*

**Slop.** *Marcus, his hands trembling with a mixture of fear and adrenaline,
finally manages to hotwire the vehicle.*
**Voice.** *Marcus touches some wires together, but the car doesn't start.*
*Marcus gets the engine going.*

**Slop.** *The interrogation was brutal, and the prisoner's spirit was
beginning to break.*
**Voice.** *The Automaton begs for the nightmare to end.* /
*The Automaton is beginning to see Liberal reason.*

Notice what happens in each: the abstraction becomes an event, the adverbs
become nothing, and the sentence gets shorter than you wanted it to be.

The right-hand sides are the right *shape*, but they are not automatically
shippable — a new string still has to be the original's words or carry an
exception. Fix the voice first, then go and find what the original said.

## Where prose meets the simulation

Three habits matter as much as the wording, and are the port's recurring
failure mode.

**Carry the roll.** The original picks a line with `pickrandom()` — which
*consumes an RNG draw*. If the simulation rolls to choose wording, it must put
the index in the Event payload and the adapter must print that line. Rolling,
discarding the index and printing a bland summary is the exact bug this
codebase keeps finding. See `docs/port/ARCHITECTURE.md`: `core/` emits
structured Events, never prose.

**Write every branch.** If the original has thirty prison stories, write thirty.
"Representative coverage" is how the voice gets sanded off. `audit_reach.py`
will find lines nothing can reach; `audit_content.py` will find content the port
dropped.

**Keep the literal seams where the original put them.** The audit matches whole
fragments against the original's own strings, and the original builds a
sentence out of consecutive `addstr()` calls. Splitting your GDScript literals
at the same points the original splits its calls is what makes a carried line
verifiably carried.

## Reference material

Read these when the job needs them; don't load them all by reflex.

- `references/registers.md` — the seven registers (news, combat, dialogue,
  interrogation, siege, menu, endgame) with verbatim exemplars of each and the
  rules specific to that register. Read before writing any substantial passage.
- `references/diction.md` — the full in-fiction lexicon, the law-driven
  vocabulary tables, the censorship tiers, the charge names, the health and
  rank words. Read when naming anything or when a word choice depends on game
  state.
- `references/mechanics.md` — how to attach prose to the simulation without
  breaking parity: event payloads, format holes, the audit's matching rules,
  and how to write an exception entry that will still make sense in a year.
  Read before touching `core/` or adding a string that isn't in `src/`.
