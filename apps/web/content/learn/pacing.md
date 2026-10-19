---
title: "Pacing: will it last until the reset?"
description: How to read the pace tick, work out whether you'll reach 100% before a window resets, and how much you can use each hour to make it last.
summary: The tick on each bar, and the arithmetic behind it.
order: 3
checked: "2026-10-19"
sources:
  - title: How do usage and length limits work? (Claude Help Center)
    url: https://support.claude.com/en/articles/11647753-how-do-usage-and-length-limits-work
  - title: Usage limit best practices (Claude Help Center)
    url: https://support.claude.com/en/articles/9797557-usage-limit-best-practices
  - title: Models, usage, and limits in Claude Code (Claude Help Center)
    url: https://support.claude.com/en/articles/14552983-models-usage-and-limits-in-claude-code
---

A limit window is a budget spread over time. Halfway through a 5-hour window, an even pace has used half of it. Ahead of that you'll run out early; behind it you have room.

## The tick

In Claude Notch every bar has a white tick that marks how far through its window you are. The bar's fill is how much you've used.

- **Fill short of the tick:** slower than an even pace. It lasts, with room to spare.
- **Fill level with the tick:** an even pace. You'd reach 100% just as it resets.
- **Fill past the tick:** faster than an even pace. At this rate you'll reach 100% before the reset.

When a bar is far enough past its tick to run out before the reset, Claude Notch says when, in orange, where the reset time was: "out ~15:40 at this pace". It waits until a tenth of the window has gone and 5% is used, so one busy minute doesn't set it off.

Drag the sliders to see it.

<div data-figure="pace"></div>

## The arithmetic

You need three numbers: the percent used, the window's length, and the time until it resets.

1. **How far through:** time gone ÷ window length. With 2 hours left of 5, 3 hours have gone: 60% through.
2. **Your rate so far:** percent used ÷ hours gone. 60% in 3 hours is 20% an hour.
3. **When you'd reach 100%:** percent left ÷ rate. 40% at 20% an hour takes 2 hours, which is exactly when it resets.
4. **To make it last:** percent left ÷ hours left. 40% over 2 hours is 20% an hour.

Now say you'd used 80% after 2 hours. That's 40% an hour, so the last 20% goes in 30 minutes, and then you'd wait 2½ hours for the reset.

The [pace calculator](/tools/pace) does this for any window, weekly ones included.

## Weekly windows

The same arithmetic works over seven days, but hardly anyone uses Claude evenly across a week. If you work weekdays, you'll be over pace on a Wednesday and well under it by Sunday. Compare the weekly bar with the working days you have left, not the hours.

## Slowing down

When the fill is well past the tick, Anthropic's own suggestions help:

- Start a new conversation rather than carrying on a very long one.
- Turn off extended thinking, Research and web search when a task doesn't need them.
- In Claude Code, use a lighter model or a lower effort level for routine work. Opus uses meaningfully more.
