
modeldir := models
.PHONY: clean verifynormal

verifynormal: | $(modeldir)
	rm -f normal-operation.pml.trail
	spin -run -a -DNOREDUCE $(modeldir)/normal-operation.pml
	rm -f pan

replayshort:
	spin -c -k normal-operation.pml.trail $(modeldir)/normal-operation.pml

replayverbose:
	spin -t0 -w -s -r -c -k normal-operation.pml.trail -p $(modeldir)/normal-operation.pml

interactive:
	spin -i $(modeldir)/normal-operation.pml
