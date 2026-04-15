# Contributing to Change Correlator

## How to Contribute

### Adding a New Collector

1. Create `collectors/<source>-collector.sh`
2. Follow the standard output format (Markdown with YAML frontmatter)
3. Include `--since` and `--until` parameters
4. Output changes to `changes/YYYY-MM-DD/` directory
5. Add tests in `tests/`

### Collector Output Format

Every change file must include:

```markdown
---
id: CHG-<SOURCE>-<DATE>-<TIME>
timestamp: YYYY-MM-DDTHH:MM:SS+TZ
source: <source-name>
severity: normal|medium|high
author: <who-made-the-change>
tags: [<relevant>, <tags>]
related_incidents: []
---

# Change Title

**Type:** Change Category
**What Changed:** Description
```

### Contributing Steps

1. Fork the repo
2. Create a branch: `git checkout -b collector/your-source`
3. Write the collector
4. Test: `bash collectors/your-source-collector.sh --help`
5. Commit: `git commit -m "Add <source> collector"`
6. Open a PR

## Priority Collectors Needed

- [ ] Terraform collector
- [ ] Helm collector
- [ ] Azure Policy collector
- [ ] Certificate collector
- [ ] DNS collector (Route53, Cloudflare)
- [ ] Slack message collector (for human changes)
- [ ] Database migration collector

## License

All contributions are licensed under MIT.
