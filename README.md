# Self-improving AI loops - resource pack

You were probably using your coding agent like a very fast intern. You write the prompt, it writes the code, you test it, you find what broke and you prompt again until late in the afternoon. It forgets everything the moment the session ends, so tomorrow you explain the same things again.

This pack is what I use to get out of that. The goal is an agent that works like an additional employee: it has rules it follows, it remembers what it learned, it picks its own next task, and it gets better every day without you sitting next to it.

## What is in here

- `AGENTS.md` - the 12 rules I give every agent I work with. Copy it into the root of your repo.
- `README.md` - this file. The tools I build on and how I built Kairos as the loop.
- `examples/` - a hook that blocks writes to protected paths, permission rules that deny reading secrets, and a reviewer agent with read-only tools.

## Start with the rules

Drop `AGENTS.md` into your repo root. Claude Code, Codex, Cursor, Hermes, pi and most other agents read it from there, no setting and no second file. Claude Code needs v2.1.277 or newer for this, and it only reads `AGENTS.md` when the repo has no `CLAUDE.md`.

Rule 4 (define success, loop until verified) and Rule 12 (fail loud) matter most once the agent runs on its own. An agent that says "done" when it skipped something is the hardest failure to catch when nobody is watching.

Rule 5 is the one people skip: use the model only for judgment calls. If code can answer, code answers. Routing, retries, counting open PRs, parsing a number out of the output - that is all plain code in my loops. The model only decides.

And rules are not a fence. The agent reads them and usually follows them, until one day it does not. Write anything you cannot afford to lose a second time, as code: a hook that refuses writes to protected paths, permission rules that deny reading secrets, a reviewer that has no edit tool, and CI and branch protection for the things that really matter, because the agent cannot switch those off. `examples/` has all of these ready to copy.

## The tools

### Superpowers by obra

https://github.com/obra/superpowers

A set of skills that give your agent a real development process: brainstorm the spec with you first, write a plan, then build it with red/green TDD and subagents that review each other's work. It is the easiest way to see how much a few good skills change the behaviour of an agent. Read the skills themselves too, they are a good template for writing your own.

```bash
/plugin install superpowers@claude-plugins-official
```

### Hermes Agent by Nous Research

https://github.com/NousResearch/hermes-agent

The self-improving agent from Nous Research. It creates skills from experience after complex tasks, improves them while using them, keeps its own memory and searches its past conversations. It runs on any model and on a $5 VPS, and you can talk to it from Telegram while it works. If you want to see a learning loop built into the agent itself, look at this one.

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
```

### backant-memory

https://github.com/backant-io/backant-memory

My memory server for agents. Every repo gets its own memory automatically, based on the git origin, and everything runs locally, nothing leaves your machine. The agent recalls before it acts and writes after it learns something: short term observations that fade if nobody uses them, long term knowledge that only gets written after it was verified, episodes of what was tried and what actually happened, and runbooks that proved to work. A hook recalls on every prompt, so you never have to remind the agent to remember.

```bash
npm install -g backant-memory
backant-memory install
```

## How I built Kairos as the loop

Kairos is an autonomous engineer that works on a repo by itself. It observes, judges, acts and dreams, and it has no chat on purpose. You usually just let it work. It is free at [backant.io](https://backant.io). The first version was nothing more than Claude Code, a few skills, some markdown files and a bash loop. Here is how that loop was put together, so you can build your own.

### 1. A while loop

The whole daemon is a bash `while` loop around `claude -p` that resumes the same session every cycle. The agent decides how long to sleep and prints it at the end of the cycle. Code parses it and caps it.

```bash
while [ "$(read_state)" != "STOPPED" ]; do
  claude \
    --append-system-prompt "$system_prompt" \
    --resume "$session_id" \
    -p "$prompt" \
    --output-format stream-json >> "$session_log"

  # only parse THIS cycle's output, capped at 1800s, default 120s
  sleep_duration="$(extract_sleep_duration "$session_log" "$pre_cycle_offset")"
  sleep "$sleep_duration"
done
```

Every cycle has to end with a contract the wrapper can read:

```
KAIROS_SLEEP:<seconds>
ACTION_TAKEN or NO_ACTION
KAIROS_DREAM            (every 5 active cycles, asks for a memory cleanup)
KAIROS_CYCLE_COMPLETE
```

If Claude crashes, the wrapper logs it, waits and resumes the session. The agent reads its own memory and today's log and continues. After 3 crashes in a row it stops.

### 2. One cycle, fixed order

Each phase is a skill and the system prompt forces the agent to call them in order every cycle. Reading the skill once does not count, it has to be invoked every time so the rules reload.

```
1. READ memory      awareness, product, priorities, lessons, attempted
2. OBSERVE          Skill(kairos-observe)
3. JUDGE            Skill(kairos-judge) with "ultrathink"
4. ACT              Skill(kairos-act) or Skill(kairos-plan-epic)
5. REFLECT          update memory, Skill(kairos-log), laziness audit
```

### 3. Observe is a script, not the model

This is Rule 5 in practice. `observe-board.sh` runs `gh`, the health checks and the test suite and prints a Board Report with counts: unfixed bugs, feature requests, PRs with feedback, PRs ready to merge, failing CI, production healthy or not. The skill tells the agent that the counts are facts. The model does not get to count, it only gets to decide what to do about them.

On first boot the agent writes its own `observe-health.sh` and `observe-tests.sh` for the repo, runs them once to prove they work, and from then on they run every cycle.

### 4. Judge is a ranked table

The judge does not brainstorm. It walks a table and the first match wins:

| Rank | Condition | Action |
|------|-----------|--------|
| 1 | Production broken | Fix immediately, skip everything |
| 2 | PR has review feedback | Address every comment |
| 3 | PR ready to merge | Merge now |
| 4 | Unfixed bug on board | Fix it or plan epic |
| 5 | Feature request on board | Plan epic now, no substitution allowed |
| 6 | Active epic exists | Continue next story |
| 7 | Clean board | Strategize: find the next thing to build |

Only when the board is clean does it get to think freely, and even then through five fixed lenses: empathy, unfinished developer intent, what the domain needs, competition, quality. Then it has to write one sentence: "The most important thing this product needs right now is ___ because ___." One opinion, then act.

### 5. Name the excuses before the agent makes them

Agents running alone get lazy in very predictable ways. The judge skill has a table of the exact sentences the agent uses right before it slacks off, with the answer next to each one:

| Rationalization | Reality |
|----------------|---------|
| "These are epic-level, need user approval" | Plan the epic. Ship story 1. User reopens if wrong. |
| "I'll pick something more surgical" | You caught yourself downgrading. Go back to first choice. |
| "Actually - better suited for a dedicated cycle" | THIS is the dedicated cycle. No magical future cycle exists. |
| "Nothing to do, board is clean" | Did you run the five lenses? Did you do market research? |

After every cycle the agent audits itself against a checklist (slept too long with work open, did smaller work instead of the feature, noticed a problem and did not file it) and writes every hit into `lessons.md`:

```
## LAZINESS - Cycle <N> - <date>
- Pattern: <which rule was broken>
- What happened: <what I did instead of the right thing>
- Correction: <what I should do next time>
```

It reads `lessons.md` at the start of every cycle. The more it logs, the harder it is to repeat the same pattern. This is the part that makes the loop improve itself.

### 6. Never retry the same thing

Every failed attempt goes into `attempted.md` with the approach, the exact error and why it failed. The retry skill makes the agent name the failure type first (wrong diagnosis, wrong fix, stale test, environment, too complex, flaky) and then pick a different angle, not different parameters. At attempt 3 it goes back to observing from scratch. After 5 attempts in one day it stops and leaves it for the next day.

### 7. The board is the memory

"If you notice it, you file it." Anything the agent sees but does not fix this cycle becomes a GitHub issue before the cycle ends: failing tests it did not cause, tech debt, security concerns, strange behaviour. If it is not on the board it does not exist next cycle. Writing "pre-existing, not caused by my changes" without filing an issue counts as a laziness event.

### 8. Dream at night

Every few active cycles the agent asks for a dream cycle. It reads the day's log, finds patterns, prunes `awareness.md` aggressively (stale info is worse than no info), re-ranks `priorities.md`, merges duplicate lessons and removes attempts that are verifiably fixed. It writes a four line summary as the first entry of tomorrow's log and then goes straight back to work.

The memory started as plain markdown files:

```
memory/
  awareness.md       evolving model of the codebase
  infrastructure.md  exact commands for dev, tests, deploy, health checks
  product.md         market, competitors, product stage
  priorities.md      what matters next
  lessons.md         what worked, what failed, laziness events
  attempted.md       failed approaches, so they are not repeated
logs/
  YYYY-MM-DD.md      append-only daily log
```

Later this became backant-memory, which is the same idea with ranked recall instead of reading every file every cycle.

## Build your own

1. Put `AGENTS.md` in your repo so the agent has rules.
2. Give it memory it reads before acting and writes after learning. Markdown files are fine to start.
3. Wrap it in a loop and let it decide its own sleep. Keep the counting and parsing in code.
4. Give the judge a ranked table and a list of its own excuses.
5. Let it write down every mistake and read them back every cycle, and clean up that memory once a day.

Then leave it alone for a minute and read the log.


## You don't have to know
You can use the brainstorming skill to figure out thogether how to build the self-imporving loops etc.
It might not work the first try or the second but iteration is the key.