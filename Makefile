
modeldir := models
.PHONY: clean verifynormal

verifynormal: | $(modeldir)
	spin -run -a -DNOREDUCE $(modeldir)/normal-operation.pml
	rm -f pan

replaytrace:
	spin -t0 -w -s -r -c -k normal-operation.pml.trail -p $(modeldir)/normal-operation.pml

interactive:
	spin -i $(modeldir)/normal-operation.pml
