import 'package:djsports/features/djaudio_player/ui/home/screens/albums.dart';
import 'package:djsports/features/djaudio_player/ui/home/screens/songs.dart';
import 'package:djsports/features/djaudio_player/ui/home/widgets/tab_indicartor.dart';
import 'package:djsports/features/djaudio_player/ui/widgets/current_song.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          0,
          MediaQuery.of(context).padding.top + 40,
          0,
          80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Listening',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 20),
            TabBar(
              controller: _tabController,
              indicator: TabIndicator(Theme.of(context).primaryColor),
              labelStyle: Theme.of(context).textTheme.headlineMedium,
              unselectedLabelStyle: Theme.of(context).textTheme.headlineSmall,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Songs'),
                Tab(text: 'Albums'),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  SongsPage(),
                  AlbumsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: const CurrentSong(),
    );
  }
}
