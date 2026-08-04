import 'package:flutter/material.dart';
import '../models/photo_item.dart';

class ImageGridCard extends StatelessWidget {
  final PhotoItem photo;
  const ImageGridCard({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    final bytes = photo.processedBytes ?? photo.originalBytes;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (bytes != null)
                    Positioned.fill(child: Image.memory(bytes, fit: BoxFit.cover))
                  else
                    const Positioned.fill(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                    
                  if (photo.isProcessing)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black45,
                        child: Center(child: CircularProgressIndicator(color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            
            // 🌟 اپڈیٹڈ: اب یہاں کسٹم نام (اگر موجود ہو) نظر آئے گا
            Text(
              (photo.customName != null && photo.customName!.isNotEmpty) 
                  ? photo.customName! 
                  : photo.name, 
              style: const TextStyle(
                fontSize: 9, 
                fontWeight: FontWeight.bold, // نام کو نمایاں کرنے کے لیے
              ), 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis
            ),
            
            if (photo.finalSizeKB != null)
              Text('${photo.finalSizeKB} KB', style: const TextStyle(fontSize: 9, color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
