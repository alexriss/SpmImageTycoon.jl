function drawLine(ctx, startX, startY, endX, endY,color){
    // ctx.save();
    ctx.strokeStyle = color;
    ctx.beginPath();
    ctx.moveTo(startX, startY);
    ctx.lineTo(endX, endY);
    ctx.stroke();
    // ctx.restore();
}

function drawBar(ctx, upperLeftCornerX, upperLeftCornerY, width, height, color){
    // ctx.save();
    ctx.fillStyle=color;
    ctx.fillRect(upperLeftCornerX, upperLeftCornerY, width, height);
    // ctx.restore();
}

function plot_histogram(canvas, width, counts) {
    // plots a bar chart to the canvas. counts are assumed to be normalized between 0 and 1
    ctx = canvas.getContext("2d");
    canvas.width = 1024;
    canvas.height = 64;
    for (let i=0, imax=counts.length; i<imax; i++) {
        drawBar(ctx, i * width * canvas.width, (1 - counts[i]) * canvas.height, width * canvas.width, counts[i] * canvas.height, '#606060');
    }
}