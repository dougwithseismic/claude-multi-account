---
title: Claude's plans and their limits
description: Free, Pro, Max, Team and Enterprise compared in the terms Anthropic itself uses, plus usage credits for when a limit runs out.
summary: What each plan gets, in Anthropic's own terms.
order: 2
checked: "2026-10-19"
sources:
  - title: Plans and pricing (claude.com)
    url: https://claude.com/pricing
  - title: Get started with Claude (Claude Help Center)
    url: https://support.claude.com/en/articles/8114491-getting-started-with-claude
  - title: What is the Pro plan? (Claude Help Center)
    url: https://support.claude.com/en/articles/8325606-what-is-the-pro-plan
  - title: What is the Max plan? (Claude Help Center)
    url: https://support.claude.com/en/articles/11049741-what-is-the-max-plan
  - title: What is the Team plan? (Claude Help Center)
    url: https://support.claude.com/en/articles/9266767-what-is-the-team-plan
  - title: Purchase and manage seats on Team plans (Claude Help Center)
    url: https://support.claude.com/en/articles/12004354-purchase-and-manage-seats-on-team-plans
  - title: What is the Enterprise plan? (Claude Help Center)
    url: https://support.claude.com/en/articles/9797531-what-is-the-enterprise-plan
  - title: Claude Fable models on your plan (Claude Help Center)
    url: https://support.claude.com/en/articles/15424964-claude-fable-models-on-your-plan
  - title: Manage usage credits for paid Claude plans (Claude Help Center)
    url: https://support.claude.com/en/articles/12429409-manage-usage-credits-for-paid-claude-plans
  - title: Manage usage credits for Team and seat-based Enterprise plans (Claude Help Center)
    url: https://support.claude.com/en/articles/12005970
---

Anthropic doesn't publish message counts for its plans. It describes each plan's limits relative to another plan, and says how far they go depends on what you ask of Claude ([How limits work](/learn/how-limits-work) explains what uses them faster). This guide sticks to Anthropic's terms. Prices change, so they're on [Anthropic's pricing page](https://claude.com/pricing) rather than here.

## At a glance

| Plan | 5-hour session | Weekly | Fable |
| --- | --- | --- | --- |
| Free | Resets every five hours; varies with demand | None mentioned | — |
| Pro | At least 5× Free | One limit across all models | Only on usage credits |
| Max 5x | 5× Pro | All models, plus one for Fable | Up to half the weekly limits |
| Max 20x | 20× Pro | All models, plus one for Fable | Up to half the weekly limits |
| Team, standard seat | 1.25× Pro | One per seat, all models | Only on usage credits |
| Team, premium seat | 6.25× Pro | One per seat, all models | Up to half the weekly limits |
| Enterprise, usage-based | No plan or seat limits; billed at API rates | — | — |

## Free

A session limit that resets every five hours. How many messages that allows varies with demand. Anthropic doesn't mention a weekly limit for Free.

## Pro

At least five times Free's usage per session, plus a weekly limit across all models. Fable is available on usage credits only.

## Max

Two sizes, with 5× or 20× Pro's usage per session. Both have a weekly limit across all models and a separate weekly limit for Fable, and up to half the weekly limits can go to Fable at no extra cost. Max and Team plans also get priority at busy times.

## Team

Limits belong to each seat, not to the team as a whole. Standard seats get 1.25× Pro's usage per session and premium seats 6.25×, which matches the pricing page's "5× standard" for premium. Each seat type has a weekly limit across all models.

Each seat belongs to one named person. Anthropic says members can't send work through another member's account to use its remaining usage.

> **Note:** Anthropic's Team article says every seat has a weekly limit across all models. On a Team seat we measured while building Claude Notch, the usage data had no all-models weekly window, only per-model ones. Claude Notch shows whichever windows an account reports.

## Enterprise

Usage-based Enterprise plans have no plan or seat limits, and usage bills at API rates. Older seat-based Enterprise plans keep per-seat limits, like Team's, until they renew.

## Usage credits

At the 5-hour, weekly or Fable limit, paid plans can carry on pay-as-you-go at standard API rates. Set it up in Settings → Usage: add funds in advance, set a monthly spend limit (or none), and turn on auto-reload if you like. The API credits that come with Max can't pay for it. On Team and seat-based Enterprise plans the organization decides whether members can use credits.

## Limits can change

Anthropic's plan pages all say it may add other limits, weekly, monthly, by model or by feature. Check [the pricing page](https://claude.com/pricing) and the articles below before relying on any of this for a purchase.
