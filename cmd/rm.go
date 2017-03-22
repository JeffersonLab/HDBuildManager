package cmd

import "github.com/spf13/cobra"

// Create the rm command
var cmdRemove = &cobra.Command{
	Use:   "rm PACKAGE...",
	Short: "Remove packages from the current settings",
	Long: `Remove packages from the current package settings.

To see the current packages use:
  hdpm show`,
	Example: `1. hdpm rm hd_utilities amptools
2. hdpm rm cmake gluex_workshops`,
	Run: runRemove,
}

func init() {
	cmdHDPM.AddCommand(cmdRemove)
}

func runRemove(cmd *cobra.Command, args []string) {
	if len(args) == 0 {
		exitNoPackages(cmd)
	}
	pkgInit()
	if !isPath(SD) {
		mk(SD)
		s := newSettings("master", "Default settings of hdpm version "+VERSION)
		s.write(SD)
		for _, pkg := range masterPackages {
			pkg.write(SD)
		}
	}
	for _, arg := range args {
		run("rm", "-f", SD+"/"+arg+".json")
	}
}
