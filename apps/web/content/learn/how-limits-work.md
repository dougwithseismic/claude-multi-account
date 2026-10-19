---
title: How Claude's usage limits work
description: The 5-hour session limit, the weekly limits, Fable's own limit, what uses them up faster, and what happens when you reach one.
summary: The 5-hour window, the weekly limits, and what resets them.
order: 1
checked: "2026-10-19"
sources:
  - title: How do usage and length limits work? (Claude Help Center)
    url: https://support.claude.com/en/articles/11647753-how-do-usage-and-length-limits-work
  - title: Plans and pricing, FAQ (claude.com)
    url: https://claude.com/pricing
  - title: What is the Pro plan? (Claude Help Center)
    url: https://support.claude.com/en/articles/8325606-what-is-the-pro-plan
  - title: What is the Max plan? (Claude Help Center)
    url: https://support.claude.com/en/articles/11049741-what-is-the-max-plan
  - title: Use Claude Code with your Pro or Max plan (Claude Help Center)
    url: https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan
  - title: Claude Fable models on your plan (Claude Help Center)
    url: https://support.claude.com/en/articles/15424964-claude-fable-models-on-your-plan
  - title: Usage limit best practices (Claude Help Center)
    url: https://support.claude.com/en/articles/9797557-usage-limit-best-practices
  - title: Models, usage, and limits in Claude Code (Claude Help Center)
    url: https://support.claude.com/en/articles/14552983-models-usage-and-limits-in-claude-code
  - title: Manage usage credits for paid Claude plans (Claude Help Center)
    url: https://support.claude.com/en/articles/12429409-manage-usage-credits-for-paid-claude-plans
  - title: What is a limit reset? (Claude Help Center)
    url: https://support.claude.com/en/articles/17007452-what-is-a-limit-reset
  - title: Claude Code Wrap-Up Allowance (Claude Help Center)
    url: https://support.claude.com/en/articles/17040437-claude-code-wrap-up-allowance
  - title: Higher usage limits and a SpaceX compute deal (Anthropic, 6 May 2026)
    url: https://www.anthropic.com/news/higher-limits-spacex
  - title: Usage (Claude for Government docs)
    url: https://claude.com/docs/government/account/usage
---

Claude's paid plans have two kinds of limit: a **session limit** that resets every five hours, and **weekly limits** that reset once a week. You can use Claude as much as you like until one of them is full.

## One pool for everything

Chats on claude.ai, the desktop and mobile apps, and Claude Code all count against the same limits. A morning in Claude Code leaves less for chat in the afternoon, and the other way round.

## The 5-hour window

The session limit covers five hours at a time. Anthropic's pricing page calls it a rolling five-hour window: when it resets, you start again from zero.

When do the five hours start? Anthropic's consumer help pages don't say. Its Claude for Government docs say the window has no timer until you send a message, and the usage data behaves that way on other plans too: an account that hasn't used Claude for a while has no reset time at all, and one appears with the first message. Claude Notch shows that as **not started**.

## Weekly limits

Pro, Max and Team plans add weekly limits. Anthropic says each account's week resets at a fixed day and time assigned to that account, not seven days after you start and not on the day you subscribed. Settings → Usage in Claude shows yours.

Plenty of guides still describe a rolling seven days. Anthropic's current pages describe a fixed time.

There can be more than one weekly limit:

- **All models:** one weekly limit across everything you use.
- **Fable:** Max plans have a separate weekly limit for Fable. On Max and Team premium seats, up to half of your weekly limits can go to Fable, which uses limits faster than other models. On Pro and Team standard seats, Fable runs only on usage credits.

Anthropic also says it may add other caps, by model or by feature, at its discretion. Claude Notch shows every window an account reports, so a new one appears as its own bar.

## What uses limits faster

Anthropic lists what makes each message count for more:

- long messages, big attachments and long conversations;
- tools such as Research and web search, and connectors;
- the model: in Claude Code, Opus uses meaningfully more;
- extended thinking and higher effort levels;
- artifacts and multi-step tasks.

[Pacing](/learn/pacing) covers how to tell, part way through a window, whether it will last until the reset.

## When you reach a limit

- **Wait for the reset.** Claude shows when that is.
- **Usage credits**, which Anthropic used to call extra usage, let paid plans carry on at standard API rates once a limit is reached. Set them up in Settings → Usage, with a prepaid balance, a monthly spend limit and optional auto-reload. On Team and Enterprise plans the organization turns them on.
- **Limit resets:** now and then Anthropic offers a **Reset for free** button that refills the 5-hour or weekly limit, on the web and in the desktop app.
- **Wrap-Up Allowance:** in Claude Code, a small allowance lets a response that's already running finish when you reach the 5-hour limit. On Pro it's at most once a week, and it's rolling out gradually.

## What changed in 2026

On 6 May 2026 Anthropic doubled Claude Code's 5-hour limits on Pro, Max, Team and seat-based Enterprise plans, and ended the lower limits Claude Code had at peak hours on Pro and Max.

## See every account at once

Claude shows one account's usage at a time, in Settings → Usage. [Claude Notch](/) shows every account's windows together, in the notch, and the [pace calculator](/tools/pace) works in any browser.
