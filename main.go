// Command matrix builds the GitHub Actions build matrix for the demo
// environment images. It asks Packagist for every shopware/core release and
// derives, per release, the Shopware version to install and the lowest PHP
// version that release supports.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"sort"
	"strings"

	"github.com/shyim/go-composer/repository"
	version "github.com/shyim/go-version"
)

const (
	// packageName is the Composer package whose releases define the matrix.
	packageName = "shopware/core"

	// minimumVersion is the oldest Shopware release we still build an image
	// for.
	minimumVersion = ">=6.6.10"
)

// phpCandidates are the PHP minor versions the base images are available for,
// lowest first. A release is built with the lowest candidate its "php"
// requirement accepts.
var phpCandidates = []string{"8.1", "8.2", "8.3", "8.4", "8.5"}

// entry is one row of the build matrix, consumed by .github/workflows/build.yml.
type entry struct {
	PHPVersion                string `json:"phpVersion"`
	ShopwareVersion           string `json:"shopwareVersion"`
	MinorShopwareVersion      string `json:"minorShopwareVersion"`
	MajorMinorShopwareVersion string `json:"majorMinorShopwareVersion"`
	IsLatestMinor             bool   `json:"isLatestMinor"`
	IsLatest                  bool   `json:"isLatest"`

	parsed *version.Version
}

type include struct {
	Include []entry `json:"include"`
}

type matrix struct {
	FailFast bool    `json:"fail-fast"`
	Matrix   include `json:"matrix"`
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "failed to generate matrix:", err)
		os.Exit(1)
	}
}

func run() error {
	pkg, err := repository.New(repository.PackagistURL, nil).GetPackage(context.Background(), packageName)
	if err != nil {
		return err
	}

	candidates, err := collect(pkg)
	if err != nil {
		return err
	}

	entries := latestPerMinor(candidates)

	// Newest first, so the first entry of a major.minor group is that group's
	// latest patch and the very first entry is the latest release overall.
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].parsed.GreaterThan(entries[j].parsed)
	})

	seenMajorMinor := map[string]bool{}
	for i := range entries {
		majorMinor := entries[i].MajorMinorShopwareVersion
		entries[i].IsLatestMinor = !seenMajorMinor[majorMinor]
		entries[i].IsLatest = i == 0
		seenMajorMinor[majorMinor] = true
	}

	out, err := json.MarshalIndent(matrix{Matrix: include{Include: entries}}, "", "  ")
	if err != nil {
		return err
	}

	fmt.Println(string(out))
	return nil
}

// collect turns the repository versions into matrix entries, dropping dev
// branches, unparsable versions and everything older than minimumVersion.
func collect(pkg *repository.Package) ([]entry, error) {
	constraint, err := version.NewConstraint(minimumVersion)
	if err != nil {
		return nil, err
	}

	var entries []entry
	for _, v := range pkg.Versions {
		raw := strings.TrimPrefix(strings.ToLower(v.Version), "v")

		if version.Stability(raw) == version.StabilityDev {
			continue
		}

		parsed, err := version.NewVersion(raw)
		if err != nil || !constraint.Check(parsed) {
			continue
		}

		phpVersion, err := lowestPHP(v.Require["php"])
		if err != nil {
			return nil, fmt.Errorf("%s %s: %w", pkg.Name, v.Version, err)
		}

		entries = append(entries, entry{
			PHPVersion:                phpVersion,
			ShopwareVersion:           raw,
			MinorShopwareVersion:      fmt.Sprintf("%d.%d.%d", parsed.Major(), parsed.Minor(), parsed.Patch()),
			MajorMinorShopwareVersion: fmt.Sprintf("%d.%d", parsed.Major(), parsed.Minor()),
			parsed:                    parsed,
		})
	}

	if len(entries) == 0 {
		return nil, fmt.Errorf("no %s release matches %s", pkg.Name, minimumVersion)
	}

	return entries, nil
}

// latestPerMinor reduces the entries to one image per minorShopwareVersion:
// the highest release of that group, preferring stable over pre-releases.
func latestPerMinor(entries []entry) []entry {
	best := map[string]entry{}
	for _, e := range entries {
		current, ok := best[e.MinorShopwareVersion]
		if !ok || preferred(e, current) {
			best[e.MinorShopwareVersion] = e
		}
	}

	picked := make([]entry, 0, len(best))
	for _, e := range best {
		picked = append(picked, e)
	}

	return picked
}

// preferred reports whether a should replace b as the representative of a
// minor version.
func preferred(a, b entry) bool {
	if a.parsed.IsPrerelease() != b.parsed.IsPrerelease() {
		return b.parsed.IsPrerelease()
	}
	return a.parsed.GreaterThan(b.parsed)
}

// lowestPHP returns the lowest supported PHP minor version accepted by a
// Composer "php" requirement such as "~8.2.0 || ~8.3.0".
func lowestPHP(requirement string) (string, error) {
	if requirement == "" {
		return "", errors.New(`no "php" requirement`)
	}

	constraint, err := version.NewConstraint(requirement)
	if err != nil {
		return "", fmt.Errorf("parsing php requirement %q: %w", requirement, err)
	}

	for _, candidate := range phpCandidates {
		v, err := version.NewVersion(candidate)
		if err != nil {
			return "", err
		}
		if constraint.Check(v) {
			return candidate, nil
		}
	}

	return "", fmt.Errorf("no known PHP version satisfies %q", requirement)
}
