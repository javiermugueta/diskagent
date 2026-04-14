package publisher

import (
	"context"
	"fmt"
	"time"

	"diskagent/internal/collector"

	"github.com/oracle/oci-go-sdk/v65/common"
	"github.com/oracle/oci-go-sdk/v65/common/auth"
	"github.com/oracle/oci-go-sdk/v65/monitoring"
)

// OCIConfig agrupa la configuración de publicación a OCI Monitoring.
type OCIConfig struct {
	Namespace     string
	CompartmentID string
	ResourceGroup string
	AuthMode      string // config | instance_principal
}

// Publisher publica métricas en OCI Monitoring.
type Publisher struct {
	client monitoring.MonitoringClient
	cfg    OCIConfig
}

func NewPublisher(cfg OCIConfig) (*Publisher, error) {
	provider, err := configProvider(cfg.AuthMode)
	if err != nil {
		return nil, err
	}

	client, err := monitoring.NewMonitoringClientWithConfigurationProvider(provider)
	if err != nil {
		return nil, fmt.Errorf("create monitoring client: %w", err)
	}

	return &Publisher{client: client, cfg: cfg}, nil
}

func configProvider(mode string) (common.ConfigurationProvider, error) {
	switch mode {
	case "", "config":
		return common.DefaultConfigProvider(), nil
	case "instance_principal":
		p, err := auth.InstancePrincipalConfigurationProvider()
		if err != nil {
			return nil, fmt.Errorf("instance principal provider: %w", err)
		}
		return p, nil
	default:
		return nil, fmt.Errorf("unsupported ORACLE_AUTH_MODE=%q (valid: config|instance_principal)", mode)
	}
}

// PublishFSGaugeMetrics publica 3 métricas por filesystem: total_bytes, used_bytes, usage_percent.
func (p *Publisher) PublishFSGaugeMetrics(ctx context.Context, fsMetrics []collector.FileSystemMetric) error {
	if len(fsMetrics) == 0 {
		return nil
	}

	now := common.SDKTime{Time: time.Now().UTC()}
	metricData := make([]monitoring.MetricDataDetails, 0, len(fsMetrics)*3)

	for _, m := range fsMetrics {
		dims := map[string]string{
			"mount_point": m.MountPoint,
			"fs_type":     m.FSType,
			"fs_name":     m.FSName,
		}

		metricData = append(metricData,
			metric("filesystem_total_bytes", p.cfg, dims, now, float64(m.TotalBytes), "bytes"),
			metric("filesystem_used_bytes", p.cfg, dims, now, float64(m.UsedBytes), "bytes"),
			metric("filesystem_usage_percent", p.cfg, dims, now, m.UsedPct, "percent"),
		)
	}

	chunkSize := 50
	for i := 0; i < len(metricData); i += chunkSize {
		j := i + chunkSize
		if j > len(metricData) {
			j = len(metricData)
		}

		req := monitoring.PostMetricDataRequest{
			PostMetricDataDetails: monitoring.PostMetricDataDetails{MetricData: metricData[i:j]},
		}
		resp, err := p.client.PostMetricData(ctx, req)
		if err != nil {
			return fmt.Errorf("post metric data: %w", err)
		}
		if *resp.FailedMetricsCount > 0 {
			return fmt.Errorf("oci rejected %d metric points", *resp.FailedMetricsCount)
		}
	}

	return nil
}

func metric(name string, cfg OCIConfig, dims map[string]string, ts common.SDKTime, value float64, unit string) monitoring.MetricDataDetails {
	md := monitoring.MetricDataDetails{
		Namespace:     common.String(cfg.Namespace),
		CompartmentId: common.String(cfg.CompartmentID),
		Name:          common.String(name),
		Dimensions:    dims,
		Datapoints: []monitoring.Datapoint{
			{Timestamp: &ts, Value: &value},
		},
		Metadata: map[string]string{"unit": unit},
	}
	if cfg.ResourceGroup != "" {
		md.ResourceGroup = common.String(cfg.ResourceGroup)
	}
	return md
}
