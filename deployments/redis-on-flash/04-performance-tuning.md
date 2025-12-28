# Redis on Flash - Performance Tuning

⚠️ **For Production Use Only** - Requires NVMe SSD storage

---

## Key Performance Principles

### 1. RAM:Flash Ratio

**Workload-based recommendations**:

| Workload | Working Set | RAM:Flash Ratio | Example |
|----------|-------------|-----------------|---------|
| Session Store | 10-20% | 1:8 to 1:10 | 10GB RAM + 80-100GB Flash |
| Cache | 20-30% | 1:5 to 1:7 | 20GB RAM + 100-140GB Flash |
| Time-Series | 15-25% | 1:6 to 1:8 | 15GB RAM + 90-120GB Flash |

### 2. Storage Requirements

**CRITICAL**: Use NVMe local SSD only
- **AWS**: i3, i3en, i4i instances
- **Azure**: Lsv2, Lsv3 VMs
- **GCP**: instances with local-ssd

**DO NOT use**: EBS, Azure Disk, GCP Persistent Disk

### 3. Value Size Optimization

| Size | RAM Hit | Flash Hit | Recommendation |
|------|---------|-----------|----------------|
| < 500B | < 1ms | 2-5ms | ❌ Use RAM-only |
| 500B-5KB | < 1ms | 1-3ms | ⚠️ Evaluate |
| > 5KB | < 1ms | 1-2ms | ✅ RoF ideal |

---

## Monitoring

### Key Metrics

1. **RAM Hit Ratio**: Target > 70%
2. **Flash Hit Ratio**: Target > 90%
3. **Latency P95**: Target < 3ms
4. **Flash IOPS**: Target < 80% capacity

### Optimization Actions

**High Latency (P95 > 5ms)**:
- Increase RAM if hit ratio < 70%
- Upgrade SSD if IOPS saturated
- Split large values
- Adjust TTLs

**High Cost**:
- Increase Flash proportion
- Implement aggressive TTLs
- Use RocksDB compression

---

## Best Practices

1. Start with 1:5 RAM:Flash ratio
2. Monitor for 1-2 weeks before adjusting
3. Use NVMe local SSD only
4. Leave 20-30% Flash headroom
5. Set up alerts for hit ratio < 70%
