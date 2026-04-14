package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"diskagent/internal/collector"
	"diskagent/internal/publisher"
)

func main() {
	interval := flag.Duration("interval", 60*time.Second, "Intervalo de publicación")
	once := flag.Bool("once", false, "Ejecuta una sola iteración")
	output := flag.String("output", "both", "Destino de salida: oci_metrics | stdout | both")
	includePseudoFS := flag.Bool("include-pseudo-fs", false, "Incluye filesystems pseudo/virtuales (proc, sysfs, tmpfs, etc.)")
	flag.Parse()

	outMode, err := parseOutputMode(*output)
	if err != nil {
		log.Fatalf("invalid --output: %v", err)
	}

	var pub *publisher.Publisher
	if outMode.OCI {
		cfg, err := loadConfigFromEnv()
		if err != nil {
			log.Fatalf("config error: %v", err)
		}
		pub, err = publisher.NewPublisher(cfg)
		if err != nil {
			log.Fatalf("publisher init error: %v", err)
		}
	}

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	run := func() error {
		metrics, err := collector.CollectFSMetrics(collector.CollectOptions{
			ExcludePseudoFS: !*includePseudoFS,
		})
		if err != nil {
			return fmt.Errorf("collect metrics: %w", err)
		}

		if outMode.Stdout {
			printMetricsStdout(metrics)
		}

		if outMode.OCI {
			if err := pub.PublishFSGaugeMetrics(ctx, metrics); err != nil {
				return fmt.Errorf("publish metrics: %w", err)
			}
			log.Printf("published %d filesystems to oci_metrics", len(metrics))
		}
		if outMode.Stdout {
			log.Printf("printed %d filesystems to stdout", len(metrics))
		}
		return nil
	}

	if *once {
		if err := run(); err != nil {
			log.Fatal(err)
		}
		return
	}

	ticker := time.NewTicker(*interval)
	defer ticker.Stop()

	for {
		if err := run(); err != nil {
			log.Printf("run error: %v", err)
		}
		select {
		case <-ctx.Done():
			log.Printf("signal received, stopping")
			return
		case <-ticker.C:
		}
	}
}

type outputMode struct {
	OCI    bool
	Stdout bool
}

func parseOutputMode(raw string) (outputMode, error) {
	v := strings.TrimSpace(strings.ToLower(raw))
	switch v {
	case "oci_metrics":
		return outputMode{OCI: true}, nil
	case "stdout":
		return outputMode{Stdout: true}, nil
	case "both":
		return outputMode{OCI: true, Stdout: true}, nil
	default:
		return outputMode{}, fmt.Errorf("must be one of: oci_metrics, stdout, both")
	}
}

func printMetricsStdout(metrics []collector.FileSystemMetric) {
	fmt.Fprintln(os.Stdout, "mount_point,fs_type,fs_name,total_bytes,used_bytes,used_percent")
	for _, m := range metrics {
		fmt.Fprintf(
			os.Stdout,
			"%s,%s,%s,%d,%d,%.2f\n",
			m.MountPoint,
			m.FSType,
			m.FSName,
			m.TotalBytes,
			m.UsedBytes,
			m.UsedPct,
		)
	}
}

func loadConfigFromEnv() (publisher.OCIConfig, error) {
	cfg := publisher.OCIConfig{
		Namespace:     os.Getenv("ORACLE_METRICS_NAMESPACE"),
		CompartmentID: os.Getenv("ORACLE_COMPARTMENT_OCID"),
		ResourceGroup: os.Getenv("ORACLE_RESOURCE_GROUP"),
		AuthMode:      os.Getenv("ORACLE_AUTH_MODE"),
	}

	if cfg.Namespace == "" {
		return cfg, fmt.Errorf("missing ORACLE_METRICS_NAMESPACE")
	}
	if cfg.CompartmentID == "" {
		return cfg, fmt.Errorf("missing ORACLE_COMPARTMENT_OCID")
	}
	return cfg, nil
}
