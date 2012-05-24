#!/bin/sh
basename=book
cd tmp
cp -r ../images ../*.tex ../*.bib .
platex ${basename}.tex && \
jbibtex ${basename} && \
platex ${basename}.tex && \
platex ${basename}.tex && \
dvipdfmx ${basename}.dvi && \
cp ${basename}.pdf ../ && \
cd .. && \
open ${basename}.pdf

