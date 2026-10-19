import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({this.source = 'app', this.reference = '', super.key});
  final String source;
  final String reference;
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _details = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _category = 'incorrect';
  bool _sending = false;
  String? _error;
  bool _sent = false;

  static const _categories = <String,String>{
    'incorrect':'Résultat incorrect',
    'inappropriate':'Contenu inadapté',
    'dangerous':'Risque pour la sécurité',
    'support':'Question ou demande de support',
  };
  static const _sources = <String>{
    'vehicle360','document','tire','trip','legal','emergency','app','other',
  };

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _error='Reconnectez-vous pour envoyer votre demande.');
      return;
    }
    setState(() {_sending=true; _error=null;});
    try {
      await Supabase.instance.client.from('app_feedback').insert({
        'user_id':userId,
        'source':_sources.contains(widget.source)?widget.source:'other',
        'source_reference':widget.reference.length>120
            ?widget.reference.substring(0,120):widget.reference,
        'category':_category,
        'description':_details.text.trim(),
      });
      if (mounted) setState(() => _sent=true);
    } catch (_) {
      if (mounted) setState(() =>
        _error='Votre signalement ne peut pas être transmis pour le moment. '
          'Conservez votre texte et réessayez.');
    } finally {
      if (mounted) setState(() => _sending=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler un problème')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_sent) ...[
              const Icon(Icons.mark_email_read_outlined,size:48),
              const SizedBox(height:12),
              const Text('Votre signalement est enregistré.',
                textAlign:TextAlign.center),
              const SizedBox(height:16),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Retour'),
              ),
            ] else Form(
              key:_formKey,
              child:Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children:[
                  const Text(
                    'Votre message sera enregistré avec la référence du '
                    'résultat concerné. Aucun document, image ou enregistrement '
                    'n’est envoyé automatiquement avec ce signalement.',
                  ),
                  const SizedBox(height:16),
                  DropdownButtonFormField<String>(
                    initialValue:_category,
                    decoration: const InputDecoration(labelText:'Motif'),
                    items:[
                      for(final entry in _categories.entries)
                        DropdownMenuItem(value:entry.key,child:Text(entry.value)),
                    ],
                    onChanged: _sending ? null : (v) {
                      if(v!=null)setState(()=>_category=v);
                    },
                  ),
                  const SizedBox(height:14),
                  TextFormField(
                    controller:_details,
                    maxLines:6,
                    maxLength:2000,
                    decoration:const InputDecoration(
                      labelText:'Décrivez le problème',
                      hintText:'Quelle information doit être revue ?',
                      alignLabelWithHint:true,
                    ),
                    validator:(v)=> (v?.trim().length??0)<5
                        ? 'Ajoutez quelques précisions.' : null,
                  ),
                  const SizedBox(height:8),
                  if(_error!=null)
                    Text(_error!,style:TextStyle(
                      color:Theme.of(context).colorScheme.error,
                    )),
                  const SizedBox(height:18),
                  FilledButton.icon(
                    onPressed:_sending?null:_send,
                    icon:const Icon(Icons.send_outlined),
                    label:Text(_sending?'Envoi…':'Envoyer le signalement'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
