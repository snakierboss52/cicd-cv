    // Ruta del archivo PDF local
    var pdfUrl = 'certificates/AI-102T00-A.pdf';

    // Referencia al contenedor HTML
    var container = document.getElementById('pdfContainer');

    pdfjsLib.getDocument(pdfUrl).promise.then(function(pdf) {
        // Renderizar la primera página
        pdf.getPage(1).then(function(page) {
            var viewport = page.getViewport({ scale: 1.5 });
            var canvas = document.createElement('canvas');
            var context = canvas.getContext('2d');
            canvas.height = viewport.height;
            canvas.width = viewport.width;
            container.appendChild(canvas);
            page.render({
                canvasContext: context,
                viewport: viewport
            });
        });
    });