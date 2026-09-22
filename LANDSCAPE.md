# The landscape - building AI employees (September 2026)

You probably started with one coding agent in one terminal. To turn that into an employee that works on its own and gets better over time you need more than a good model. You need about ten pieces around it, and every vendor sells a different slice of them. This page walks through each piece: what it is, why you need it, what the options are right now, and what we use.

```
            ┌──────────────────────────────────────────────┐
            │  10. Organization   several agents as a team │
            └──────────────────────────────────────────────┘
   ┌───────────┐  ┌──────────────────────────────┐  ┌──────────────┐
   │ 9. Guard- │  │  5. Loop      wakes it up     │  │ 8. Evals and │
   │   rails   │  │  ┌─────────────────────────┐  │  │ observability│
   │           │  │  │ 1. Harness  + the model │  │  │              │
   │ perms,    │  │  │ 2. Rules    3. Skills   │  │  │ is it getting│
   │ budgets,  │  │  │ 4. Memory   6. Tools    │  │  │ better or    │
   │ approvals │  │  └─────────────────────────┘  │  │ just busier? │
   └───────────┘  │  7. Sandbox   where it runs   │  └──────────────┘
                  └──────────────────────────────┘
```

## How an agent improves itself

Self-improvement is not a feature you install. It is a cycle that runs through several of these pieces:

1. The agent **acts** (harness, tools, sandbox).
2. It **records** what it tried, what it expected and what actually happened (memory).
3. It **consolidates**: repeated lessons become rules or skills, stale knowledge gets pruned (memory, skills, a nightly "dream" job).
4. It **reads that back** before the next action (rules, skills, memory recall).
5. You **measure** whether the numbers moved (evals). Without this step you cannot tell an agent that improves from one that just writes a lot of notes.

## 1. Harness

The program that runs the model in a loop with tools: reads files, runs commands, calls tools, manages context. This is what turns a model into an agent. You can use a finished coding agent, build on an SDK, or rent a hosted one.

| Option | What it is | Pick it when |
|---|---|---|
| [Claude Code](https://code.claude.com/docs/en/best-practices) | The coding agent itself, scriptable with `claude -p` | You want the fastest start and a loop in bash is enough |
| [Claude Agent SDK](https://platform.claude.com/docs/en/agent-sdk/overview) | Claude Code's loop as a library: tools, hooks, subagents, skills, sessions | You want to own the loop in your own product and infrastructure |
| [Claude Managed Agents](https://platform.claude.com/docs/en/managed-agents/overview) | Hosted harness with sandbox, session log, scheduled runs, memory stores | You want the loop without running servers (beta) |
| [OpenAI Agents SDK](https://openai.github.io/openai-agents-python/) / [Agents API](https://developers.openai.com/api/docs/guides/agents) | The same idea on OpenAI, Codex harness as a service | You are on OpenAI models |
| [pi](https://github.com/earendil-works/pi) | Minimal harness, four tools, SDK and RPC modes | You want to read and understand a whole harness, or need a fallback |
| [Deep Agents](https://github.com/langchain-ai/deepagents) | Harness on top of LangGraph's checkpointed runtime | You need to switch models freely |

Also fine if you are already on that stack: [Google ADK 2.0](https://adk.dev/2.0/), [Cloudflare Agents](https://blog.cloudflare.com/project-think/), [Mastra](https://mastra.ai/), Microsoft Agent Framework.

**We use:** Claude Code as the main harness and pi as the fallback. Kairos runs on Claude Code on purpose, because in our experience it is less prone to prompt injection, and that is a must have when nobody is watching the agent.

## 2. Rules

The standing instructions the agent reads at the start of every session: how to work, what never to do, how to report. Cheap to write and the biggest change in behaviour per line you add.

| Option | What it is |
|---|---|
| [AGENTS.md](https://agents.md) | The open standard file for repo instructions |

**We use:** the 12 rules in [`AGENTS.md`](AGENTS.md) in this pack, globally and per repo.

## 3. Skills

Procedural knowledge the agent loads only when it needs it: how to debug, how to plan an epic, how to review a PR. Rules say what to be, skills say how to do a task. This is also where most of the self-improvement ends up, because a lesson that keeps repeating should become a skill.

| Option | What it is |
|---|---|
| [Agent Skills](https://agentskills.io) | The open `SKILL.md` format, works across ~40 agents |
| [Superpowers](https://github.com/obra/superpowers) | A full development process as skills: brainstorm, plan, TDD, subagent development |
| [BMAD Method](https://github.com/bmad-code-org/BMAD-METHOD) | Planning agents and workflows: brief, PRD, architecture, epics, stories |
| [Ponytail](https://github.com/DietrichGebert/ponytail) | Keeps the agent from over-engineering: YAGNI, stdlib first, shortest diff |
| [Anthropic skills](https://github.com/anthropics/skills) | Official examples, including a skill for writing skills |

Watch out: skill libraries rot. Skills drift from the code, shadow each other or teach the wrong thing. Curate them, do not just pile them up. Good read: ["Your agent skill library is quietly rotting"](https://lowpassfilter.substack.com/p/your-agent-skill-library-is-quietly).

**We use:** Superpowers, Ponytail, BMAD for planning, our own `kairos-*` skills, and the `pr-review-toolkit` and `security-guidance` plugins.

## 4. Memory

What survives between sessions. There are a few kinds and you want all of them: facts about the codebase or business, episodes (what was tried and what happened), procedures that proved to work, and a model of the people the agent works with. The hard part is not storing, it is recalling the right thing at the right time and forgetting what is stale.

| Option | What it is | Pick it when |
|---|---|---|
| [backant-memory](https://github.com/backant-io/backant-memory) | Local, repo-scoped vector memory over CLI, recall hook on every prompt | Coding agents, data must stay on your machine |
| [Mem0](https://github.com/mem0ai/mem0) | The most used memory layer, extracts facts from conversations | You want a hosted or library memory with little setup |
| [Graphiti](https://github.com/getzep/graphiti) | Temporal knowledge graph, invalidates old facts instead of deleting them | Business processes where facts change over time |
| [Honcho](https://github.com/plastic-labs/honcho) | Models users and agents as peers | Customer facing agents that need to know who they talk to |
| [Letta Code](https://github.com/letta-ai/letta-code) | Memory as git-backed "context repositories" | You like memory you can diff and review |
| [Managed Agents memory + Dreams](https://platform.claude.com/docs/en/managed-agents/dreams) | Hosted memory stores, a job rewrites them from up to 100 past sessions | You are on Managed Agents |

Start simple: markdown files (`lessons.md`, `attempted.md`, `priorities.md`) are enough to start. Move to a memory server once they get too big to read every cycle.

**We use:** backant-memory with four hooks (digest at session start, recall on every prompt, summaries on compaction and session end), embeddings computed locally with Ollama.

## 5. Loop and scheduling

What wakes the agent up, decides when it runs again and survives crashes. This is the difference between an assistant and an employee.

| Option | What it is | Pick it when |
|---|---|---|
| A `while` loop around codex/claude cli | See the Kairos section in the [README](README.md) | One agent, one machine, start today |
| Claude Code `/loop` and `/schedule` | Recurring prompts and scheduled cloud agents built into Claude Code | Recurring jobs without writing a daemon |
| [Temporal](https://temporal.io) | The heavyweight standard for durable execution | Many agents, long running, you already run infrastructure |
| [Inngest](https://www.inngest.com) | Durable steps with little operations work, plus AgentKit | Serverless teams |
| [Restate](https://restate.dev) | Temporal-like guarantees with much less infrastructure | You want durability without a Temporal cluster |
| [Cloudflare Workflows](https://developers.cloudflare.com/workflows/) / [Vercel Workflow SDK](https://vercel.com/docs/workflows) | Durable workflows on those platforms, can sleep for months and wait for approval | You are already on that platform |

**We use:** Kairos (`npx backant-kairos`), which started as the bash loop in the README. launchd keeps our daemons alive across sleep and reboots.

## 6. Tools and context

How the agent touches the world and how it knows current facts. Your training data is always out of date, so the agent needs a way to read current docs.

| Option | What it is |
|---|---|
| [MCP Registry](https://registry.modelcontextprotocol.io/) | Official server directory, still preview. Companies should run a private one |
| Plain CLIs (`gh`, `aws`, `wrangler`) | Often better than an MCP server: agents already know them and they cost no context |
| [Context7](https://context7.com) | Version specific library docs over MCP |
| [Nia](https://github.com/nozomio-labs/nia) | Indexes whole repos and docs sites for the agent to search |
| [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) | Lets the agent open, click and inspect the real app to verify its work |

**We use:** `gh` as the board (issues are the agent's to-do list and memory of open work), Nia for docs, Chrome DevTools MCP and Claude in Chrome for checking the running app, plus the PostHog, Cloudflare, AWS and Terraform plugins.

## 7. Sandbox

Where the agent runs code. On your laptop it can read your SSH keys and every secret you have. In a sandbox the worst case is a deleted sandbox.

| Option | What it is |
|---|---|
| [E2B](https://e2b.dev) | Fast microVM sandboxes, sessions up to 24h |
| [Daytona](https://www.daytona.io) | Sandboxes without session limits, GPUs available |
| [Modal Sandboxes](https://modal.com/docs/guide/sandboxes) | Nothing to pay while idle, GPUs available |
| [Vercel Sandbox](https://vercel.com/docs/vercel-sandbox) | microVMs billed for active CPU only |
| [Cloudflare Sandbox SDK](https://developers.cloudflare.com/sandbox/) | Credentials injected through an egress proxy, so the agent never sees them |
| Git worktrees + Docker | Free and local, isolates the code but not your network or secrets |

**We use:** one git worktree per task, so parallel agents never step on each other.

## 8. Evals and observability

How you know the agent got better and not just busier. Traces show what it did, evals turn that into a number you can compare week over week. The first eval set is usually just 20 to 50 real tasks where you know the right outcome.

| Option | What it is |
|---|---|
| [Inspect AI](https://inspect.aisi.org.uk/) | Open eval framework from the UK AI Security Institute, Docker sandboxes, 200+ ready evals |
| [Braintrust](https://www.braintrust.dev/) | Turns production traces into evals that run in CI |
| [Langfuse](https://langfuse.com) | Open source tracing and evals, self hostable |
| [promptfoo](https://www.promptfoo.dev) | Evals plus red teaming, open source |
| [PostHog LLM analytics](https://posthog.com/docs/llm-analytics) / [Phoenix](https://github.com/Arize-ai/phoenix) | Traces, cost and latency next to your product analytics |

**We use:** `backant eval run` every week. It reports compliance with the policy in `.backant.toml`, cost per turn and per PR, outcomes (PRs opened, merged, CI green or red, time to merge), and replays a small set of scenarios against the current memory to catch quiet regressions. backant-memory stores expected vs actual for every attempt, so surprises are visible.

## 9. Guardrails

An autonomous agent reads untrusted content all day: issues, web pages, dependencies. The rule to remember is the **lethal trifecta**: private data, untrusted content and a way to send data out. Any two are fine. All three in one session means a prompt injection can steal your data. Don't count on the model refusing. Lock down the environment instead.

| Resource | What it gives you |
|---|---|
| [The lethal trifecta](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/) | The one framing everyone on the team should know |
| [Agents Rule of Two](https://simonwillison.net/2025/Nov/2/new-prompt-injection-papers/) | Meta's rule: at most two of the three per session, otherwise a human approves |
| [Design patterns for securing LLM agents](https://simonwillison.net/2025/Jun/13/prompt-injection-design-patterns/) | Concrete architectures that hold up against injection |
| [OWASP Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/) | Checklist including memory poisoning and goal hijacking |
| [How we contain Claude](https://www.anthropic.com/engineering/how-we-contain-claude) / [Claude Code auto mode](https://www.anthropic.com/engineering/claude-code-auto-mode) | How Anthropic isolates its own agents |

Governance matters as much as security: approval gates for risky actions, a cost cap per turn, a kill switch, and a log of every decision with its reason.

**We use:** approval gates in `.backant.toml` (merging and migrations are off by default until you trust it), a cost cap per turn, have a code-based kill switch, and every decision logged with the reason it was made.

## 10. Organization

Several agents working together: one plans, one builds, one reviews. A reviewer that is a different agent catches what the builder talks itself into. This is where agents start to look like a company.

| Resource | What it is |
|---|---|
| [Harness design for long-running apps](https://www.anthropic.com/engineering/harness-design-long-running-apps) | Anthropic's planner, generator and evaluator setup |
| [Project Vend phase two](https://www.anthropic.com/research/project-vend-2) | An AI-run shop that became profitable once it got procedures, tools and a manager agent |
| [A2A](https://a2a-protocol.org/latest/) | Protocol for agents from different vendors to talk to each other |
| Subagents in Claude Code / the Agent SDK | The simplest way to split work between agents |

**We use:** parallel agents in their own worktrees, and an internal office runtime where agents are hired into roles, get work assigned, and a separate reviewer and CI gates have to pass before anything lands.

---

## Reading list

Start with the first three, in order.

1. [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents) (Anthropic). Workflows vs agents, and when you need which.
2. [12-factor agents](https://github.com/humanlayer/12-factor-agents) (HumanLayer). Own your prompts, your context and your control flow.
3. [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) (Anthropic). How an agent keeps working across many context windows.
4. [Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) (Anthropic). What goes into the context window and what stays out.
5. [Writing tools for agents](https://www.anthropic.com/engineering/writing-tools-for-agents) (Anthropic).
6. [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) (Anthropic).
7. [Scaling Managed Agents: decoupling the brain from the hands](https://www.anthropic.com/engineering/managed-agents) (Anthropic).
8. [Harness engineering](https://openai.com/index/harness-engineering/) (OpenAI). A team that let agents write the code and focused on the harness around them.
9. [A practical guide to building agents](https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf) (OpenAI, PDF).
10. [Claude Code best practices](https://code.claude.com/docs/en/best-practices).

---

## Go deeper

### Research on agents that improve themselves

Most of what a loop like Kairos does has a paper behind it. Read these if you want to know why lessons files, skill libraries and reflection steps work.

| Paper | What it shows |
|---|---|
| [Agentic Context Engineering](https://arxiv.org/abs/2510.04618) (ICLR 2026) | Treats the context as a playbook that gets generated, reflected on and curated, without losing detail over time |
| [GEPA](https://arxiv.org/abs/2507.19457) (2025) | Improves prompts by reflecting on failed runs, beats reinforcement learning with far fewer tries. Available in [DSPy](https://dspy.ai) |
| [A Self-Improving Coding Agent](https://arxiv.org/abs/2504.15228) (2025) | A coding agent that edits its own code and gets better on benchmarks |
| [Darwin Gödel Machine](https://arxiv.org/abs/2505.22954) (2025) | Keeps an archive of agent versions and evolves them, keeps what scores better |
| [Self-Evolving Coding Agents](https://arxiv.org/abs/2608.03392) (2026) | Coding agents that learn from their own history of solved issues |
| [Recursive Self-Improvement in AI](https://arxiv.org/abs/2607.07663) (2026) | Overview from simple self-refinement up to agents running their own research loops |

### Benchmarks for AI employees

Coding benchmarks tell you little about an agent that should do a job. These measure work.

| Benchmark | What it measures |
|---|---|
| [TheAgentCompany](https://the-agent-company.com) | Agents doing the tasks of employees in a simulated software company: browsing, coding, messaging colleagues |
| [GDPval](https://arxiv.org/abs/2510.04374) | Real work products from 44 occupations, graded by people from those jobs |
| [Vending-Bench 2](https://andonlabs.com/evals/vending-bench-2) | Running a small business over a long time without losing the plot |
| [τ²-bench](https://github.com/sierra-research/tau2-bench) | Customer service agents following company policy with a simulated customer |
| [APEX-Agents](https://techcrunch.com/2026/01/22/are-ai-agents-ready-for-the-workplace-a-new-benchmark-raises-doubts/) | Consulting, banking and law tasks. Most models still failed in January 2026 |

### Open source agents worth reading

The fastest way to understand a harness is to read one.

| Project | Why read it |
|---|---|
| [mini-swe-agent](https://github.com/SWE-agent/mini-swe-agent) | A coding agent in about 100 lines of Python that only uses bash. Read it in one sitting |
| [OpenHands](https://github.com/OpenHands/OpenHands) | Full open platform for coding agents, with sandboxes and a web UI |
| [Goose](https://github.com/aaif-goose/goose) | Block's open agent, now under the Agentic AI Foundation |
| [Codex CLI](https://github.com/openai/codex) / [Gemini CLI](https://github.com/google-gemini/gemini-cli) | The big vendors' coding agents, both open source |
| [Aider](https://github.com/Aider-AI/aider) | Git-native pair programmer, every change is a commit |
| [OpenClaw](https://github.com/openclaw/openclaw) | Personal agent that runs on your machine and talks to you through chat apps |

### Beyond code

Most employees don't live in a terminal. For agents doing business work:

| Tool | What it is |
|---|---|
| [Browser Use](https://github.com/browser-use/browser-use) / [Stagehand](https://github.com/browserbase/stagehand) | Let agents use websites and web apps that have no API |
| [Claude in Chrome](https://claude.com/claude-in-chrome) | Claude working inside your own browser |
| [LiteLLM](https://github.com/BerriAI/litellm) / [OpenRouter](https://openrouter.ai) | One API for many models, with budgets per key. Useful for fallbacks and cost control |
| [DSPy](https://dspy.ai) + [GEPA](https://github.com/gepa-ai/gepa) | Optimize prompts against your eval set instead of by hand |


### Learn

| Resource | What it is |
|---|---|
| [Your AI product needs evals](https://hamel.dev/blog/posts/evals/) and the [evals FAQ](https://hamel.dev/blog/posts/evals-faq/) (Hamel Husain) | The most practical writing on building evals from your own data |
| [Advanced context engineering for coding agents](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md) (Dex Horthy) | Research, plan, implement, and keep the context small on purpose |
| [Hugging Face Agents Course](https://huggingface.co/learn/agents-course) | Free course from the basics to multi-agent systems |
| [Anthropic Academy](https://anthropic.skilljar.com/) | Free courses on the Claude API, MCP and Claude Code |
| [AI Engineering](https://github.com/chiphuyen/aie-book) (Chip Huyen) | The book on building products on top of models, including evals and agents |
| [LLM Powered Autonomous Agents](https://lilianweng.github.io/posts/2023-06-23-agent/) (Lilian Weng) | The classic overview of planning, memory and tools. Still holds up |
| [Software Is Changing (Again)](https://www.youtube.com/watch?v=LCEmiRjPEtQ) (Andrej Karpathy) | The autonomy slider: how much you let the agent do on its own |
| [Simon Willison](https://simonwillison.net) and [Latent Space](https://www.latent.space) | Follow these two to stay current without reading everything |

# Strong recommedation to look at
https://typesafe.ai/
