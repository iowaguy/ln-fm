
modeldir := models
.PHONY: clean verifynormal

verifynormal: | $(modeldir)
	spin -run -a -DNOREDUCE $(modeldir)/normal-operation.pml
	mv normal-operation.pml.trail $(modeldir)
	rm pan

replaytrace:
	spin -t0 -w -s -r -c $(modeldir)/normal-operation.pml

interactive:
	spin -i $(modeldir)/normal-operation.pml

clean:
	rm models/*.trail
