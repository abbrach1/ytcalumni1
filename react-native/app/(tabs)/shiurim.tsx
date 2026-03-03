import React, { useState, useEffect, useMemo } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  ActivityIndicator,
  FlatList,
  Linking,
  RefreshControl,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors } from '../../constants/Colors';
import { useAudioPlayer } from '../../hooks/useAudioPlayer';
import { fetchShiurim, Shiur } from '../../services/firebase';
import { fetchAllPlaybackPositions, formatTime } from '../../managers/AudioPlayerManager';
import { auth } from '../../services/firebaseConfig';
import { doc, getDoc, setDoc, updateDoc, arrayUnion, arrayRemove } from 'firebase/firestore';
import { db } from '../../services/firebaseConfig';

type SortOrder = 'dateDesc' | 'dateAsc' | 'titleAZ' | 'rebbeAZ';

const sortLabels: Record<SortOrder, string> = {
  dateDesc: 'Newest First',
  dateAsc: 'Oldest First',
  titleAZ: 'Title A-Z',
  rebbeAZ: 'Rebbe A-Z',
};

export default function ShiurimScreen() {
  const audioPlayer = useAudioPlayer();

  const [shiurim, setShiurim] = useState<Shiur[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchText, setSearchText] = useState('');
  const [sortOrder, setSortOrder] = useState<SortOrder>('dateDesc');
  const [showSavedOnly, setShowSavedOnly] = useState(false);
  const [showInProgressOnly, setShowInProgressOnly] = useState(false);
  const [savedShiurimIds, setSavedShiurimIds] = useState<Set<string>>(new Set());
  const [playbackPositions, setPlaybackPositions] = useState<Record<string, number>>({});
  const [showSortMenu, setShowSortMenu] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  const loadData = async () => {
    try {
      const data = await fetchShiurim();
      setShiurim(data);
      const positions = await fetchAllPlaybackPositions();
      setPlaybackPositions(positions);
      await loadSavedShiurim();
    } catch (error) {
      console.error('Error loading shiurim:', error);
    }
    setIsLoading(false);
  };

  const loadSavedShiurim = async () => {
    const userId = auth.currentUser?.uid;
    if (!userId) return;
    try {
      const snap = await getDoc(doc(db, 'users', userId, 'preferences', 'savedShiurim'));
      if (snap.exists()) {
        const savedIds = snap.data()?.savedShiurIds ?? [];
        setSavedShiurimIds(new Set(savedIds));
      }
    } catch (error) {
      console.error('Error loading saved shiurim:', error);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const onRefresh = async () => {
    setRefreshing(true);
    await loadData();
    setRefreshing(false);
  };

  const toggleSave = async (shiurId: string) => {
    const userId = auth.currentUser?.uid;
    if (!userId) return;

    const docRef = doc(db, 'users', userId, 'preferences', 'savedShiurim');
    const newSet = new Set(savedShiurimIds);

    if (newSet.has(shiurId)) {
      newSet.delete(shiurId);
      setSavedShiurimIds(newSet);
      updateDoc(docRef, { savedShiurIds: arrayRemove(shiurId) }).catch(console.error);
    } else {
      newSet.add(shiurId);
      setSavedShiurimIds(newSet);
      setDoc(docRef, { savedShiurIds: arrayUnion(shiurId) }, { merge: true }).catch(console.error);
    }
  };

  const filteredShiurim = useMemo(() => {
    let result = [...shiurim];

    if (searchText) {
      const q = searchText.toLowerCase();
      result = result.filter(
        (s) =>
          s.title.toLowerCase().includes(q) ||
          s.rebbe.toLowerCase().includes(q) ||
          s.tags.some((t) => t.toLowerCase().includes(q)) ||
          (s.series?.toLowerCase().includes(q) ?? false)
      );
    }

    if (showSavedOnly) {
      result = result.filter((s) => savedShiurimIds.has(s.id));
    }
    if (showInProgressOnly) {
      result = result.filter((s) => (playbackPositions[s.id] ?? 0) > 0);
    }

    switch (sortOrder) {
      case 'dateDesc': result.sort((a, b) => b.date.localeCompare(a.date)); break;
      case 'dateAsc': result.sort((a, b) => a.date.localeCompare(b.date)); break;
      case 'titleAZ': result.sort((a, b) => a.title.localeCompare(b.title)); break;
      case 'rebbeAZ': result.sort((a, b) => a.rebbe.localeCompare(b.rebbe)); break;
    }

    return result;
  }, [shiurim, searchText, sortOrder, showSavedOnly, showInProgressOnly, savedShiurimIds, playbackPositions]);

  const renderShiurItem = ({ item: shiur }: { item: Shiur }) => {
    const isCurrent = audioPlayer.currentShiurId === shiur.id;
    const isSaved = savedShiurimIds.has(shiur.id);
    const savedPos = playbackPositions[shiur.id] ?? 0;

    return (
      <View style={styles.shiurRow}>
        {/* Header row */}
        <View style={styles.shiurHeader}>
          <View style={[styles.shiurIcon, isCurrent && styles.shiurIconActive]}>
            <Ionicons
              name={isCurrent && audioPlayer.isPlaying ? 'pulse' : 'headset'}
              size={20}
              color={isCurrent ? Colors.navy : Colors.navyOpacity(0.5)}
            />
          </View>

          <View style={styles.shiurInfo}>
            <Text style={styles.shiurTitle} numberOfLines={2}>{shiur.title}</Text>
            <Text style={styles.shiurRebbe}>{shiur.rebbe}</Text>
            <View style={styles.shiurMeta}>
              <Text style={styles.shiurDate}>{shiur.date}</Text>
              {shiur.series ? (
                <>
                  <Text style={styles.metaDot}>{'\u2022'}</Text>
                  <Text style={styles.shiurSeries}>{shiur.series}</Text>
                </>
              ) : null}
            </View>
          </View>

          <TouchableOpacity onPress={() => toggleSave(shiur.id)}>
            <Ionicons
              name={isSaved ? 'bookmark' : 'bookmark-outline'}
              size={22}
              color={isSaved ? Colors.gold : Colors.navyOpacity(0.3)}
            />
          </TouchableOpacity>
        </View>

        {/* Tags */}
        {shiur.tags.length > 0 && (
          <ScrollView horizontal showsHorizontalScrollIndicator={false}>
            <View style={styles.tagRow}>
              {shiur.tags.map((tag) => (
                <View key={tag} style={styles.tagChip}>
                  <Text style={styles.tagChipText}>{tag}</Text>
                </View>
              ))}
            </View>
          </ScrollView>
        )}

        {/* Resume indicator */}
        {savedPos > 0 && !isCurrent && (
          <View style={styles.resumeRow}>
            <Ionicons name="time" size={14} color={Colors.gold} />
            <Text style={styles.resumeText}>Resume from {formatTime(savedPos)}</Text>
          </View>
        )}

        {/* Action buttons */}
        <View style={styles.actionRow}>
          {shiur.audioUrl && (
            <TouchableOpacity
              style={[styles.playBtn, isCurrent && styles.playBtnActive]}
              onPress={() => {
                if (isCurrent) {
                  audioPlayer.togglePlayPause();
                } else {
                  audioPlayer.play(shiur);
                }
              }}
            >
              <Ionicons
                name={isCurrent && audioPlayer.isPlaying ? 'pause' : 'play'}
                size={16}
                color={Colors.cream}
              />
              <Text style={styles.playBtnText}>
                {isCurrent
                  ? (audioPlayer.isPlaying ? 'Pause' : 'Play')
                  : (savedPos > 0 ? 'Resume' : 'Play')}
              </Text>
            </TouchableOpacity>
          )}

          {shiur.pdfUrl ? (
            <TouchableOpacity
              style={styles.pdfBtn}
              onPress={() => Linking.openURL(shiur.pdfUrl!)}
            >
              <Ionicons name="document-text" size={14} color={Colors.navy} />
              <Text style={styles.pdfBtnText}>PDF</Text>
            </TouchableOpacity>
          ) : null}
        </View>
      </View>
    );
  };

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={Colors.navy} />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.headerSection}>
        <Text style={styles.headerTitle}>Shiurim</Text>

        {/* Search bar */}
        <View style={styles.searchRow}>
          <View style={styles.searchBar}>
            <Ionicons name="search" size={18} color={Colors.navyOpacity(0.4)} />
            <TextInput
              style={styles.searchInput}
              value={searchText}
              onChangeText={setSearchText}
              placeholder="Search by title, rebbe, or topic..."
              placeholderTextColor={Colors.navyOpacity(0.4)}
            />
            {searchText !== '' && (
              <TouchableOpacity onPress={() => setSearchText('')}>
                <Ionicons name="close-circle" size={18} color={Colors.navyOpacity(0.4)} />
              </TouchableOpacity>
            )}
          </View>
        </View>

        {/* Quick filter chips */}
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          <View style={styles.chipRow}>
            <TouchableOpacity
              style={[styles.chip, showSavedOnly && styles.chipActive]}
              onPress={() => { setShowSavedOnly(!showSavedOnly); setShowInProgressOnly(false); }}
            >
              <Ionicons name="bookmark" size={12} color={showSavedOnly ? Colors.navy : Colors.cream} />
              <Text style={[styles.chipText, showSavedOnly && styles.chipTextActive]}>Saved</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[styles.chip, showInProgressOnly && styles.chipActive]}
              onPress={() => { setShowInProgressOnly(!showInProgressOnly); setShowSavedOnly(false); }}
            >
              <Ionicons name="time" size={12} color={showInProgressOnly ? Colors.navy : Colors.cream} />
              <Text style={[styles.chipText, showInProgressOnly && styles.chipTextActive]}>In Progress</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.chip}
              onPress={() => setShowSortMenu(!showSortMenu)}
            >
              <Ionicons name="swap-vertical" size={12} color={Colors.cream} />
              <Text style={styles.chipText}>{sortLabels[sortOrder]}</Text>
            </TouchableOpacity>
          </View>
        </ScrollView>

        {/* Sort menu dropdown */}
        {showSortMenu && (
          <View style={styles.sortMenu}>
            {(Object.keys(sortLabels) as SortOrder[]).map((key) => (
              <TouchableOpacity
                key={key}
                style={styles.sortMenuItem}
                onPress={() => { setSortOrder(key); setShowSortMenu(false); }}
              >
                <Text style={[styles.sortMenuText, sortOrder === key && styles.sortMenuTextActive]}>
                  {sortLabels[key]}
                </Text>
                {sortOrder === key && <Ionicons name="checkmark" size={16} color={Colors.gold} />}
              </TouchableOpacity>
            ))}
          </View>
        )}
      </View>

      {/* List */}
      {filteredShiurim.length === 0 ? (
        <View style={styles.emptyState}>
          <Ionicons name="headset" size={48} color={Colors.navyOpacity(0.3)} />
          <Text style={styles.emptyTitle}>
            {showSavedOnly ? 'No saved shiurim' : showInProgressOnly ? 'No shiurim in progress' : 'No shiurim found'}
          </Text>
          <Text style={styles.emptyMessage}>
            {showSavedOnly
              ? 'Bookmark shiurim to access them here'
              : showInProgressOnly
              ? 'Start listening to track your progress'
              : 'Try adjusting your search or filters'}
          </Text>
        </View>
      ) : (
        <FlatList
          data={filteredShiurim}
          keyExtractor={(item) => item.id}
          renderItem={renderShiurItem}
          contentContainerStyle={{ padding: 16, paddingBottom: audioPlayer.currentShiurId ? 120 : 20 }}
          ItemSeparatorComponent={() => <View style={{ height: 12 }} />}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.navy} />}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.cream,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: Colors.cream,
  },
  headerSection: {
    backgroundColor: Colors.navy,
    paddingTop: 60,
    paddingHorizontal: 16,
    paddingBottom: 16,
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: Colors.cream,
    fontFamily: 'serif',
    marginBottom: 12,
  },
  searchRow: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 12,
  },
  searchBar: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.white,
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
    gap: 8,
  },
  searchInput: {
    flex: 1,
    fontSize: 15,
    color: Colors.navy,
  },
  chipRow: {
    flexDirection: 'row',
    gap: 8,
  },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 12,
    paddingVertical: 8,
    backgroundColor: Colors.creamOpacity(0.2),
    borderRadius: 20,
  },
  chipActive: {
    backgroundColor: Colors.gold,
  },
  chipText: {
    fontSize: 12,
    fontWeight: '500',
    color: Colors.cream,
  },
  chipTextActive: {
    color: Colors.navy,
  },
  sortMenu: {
    backgroundColor: Colors.white,
    borderRadius: 12,
    marginTop: 8,
    padding: 4,
  },
  sortMenuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 10,
    paddingHorizontal: 16,
  },
  sortMenuText: {
    fontSize: 14,
    color: Colors.navy,
  },
  sortMenuTextActive: {
    color: Colors.gold,
    fontWeight: '600',
  },
  // Shiur row
  shiurRow: {
    backgroundColor: Colors.white,
    borderRadius: 12,
    padding: 16,
    gap: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.06,
    shadowRadius: 8,
    elevation: 2,
  },
  shiurHeader: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 12,
  },
  shiurIcon: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: Colors.navyOpacity(0.1),
    alignItems: 'center',
    justifyContent: 'center',
  },
  shiurIconActive: {
    backgroundColor: Colors.gold,
  },
  shiurInfo: {
    flex: 1,
  },
  shiurTitle: {
    fontSize: 15,
    fontWeight: '600',
    color: Colors.navy,
  },
  shiurRebbe: {
    fontSize: 13,
    color: Colors.navyOpacity(0.7),
    marginTop: 2,
  },
  shiurMeta: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginTop: 4,
  },
  shiurDate: {
    fontSize: 11,
    color: Colors.navyOpacity(0.5),
  },
  metaDot: {
    color: Colors.navyOpacity(0.3),
    fontSize: 11,
  },
  shiurSeries: {
    fontSize: 11,
    color: Colors.gold,
  },
  tagRow: {
    flexDirection: 'row',
    gap: 6,
  },
  tagChip: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    backgroundColor: Colors.navyOpacity(0.06),
    borderRadius: 4,
  },
  tagChipText: {
    fontSize: 10,
    color: Colors.navyOpacity(0.6),
  },
  resumeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  resumeText: {
    fontSize: 11,
    color: Colors.navyOpacity(0.6),
  },
  actionRow: {
    flexDirection: 'row',
    gap: 10,
  },
  playBtn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    backgroundColor: Colors.navy,
    borderRadius: 8,
    paddingVertical: 10,
  },
  playBtnActive: {
    backgroundColor: Colors.gold,
  },
  playBtnText: {
    fontSize: 13,
    fontWeight: '600',
    color: Colors.cream,
  },
  pdfBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 16,
    paddingVertical: 10,
    backgroundColor: Colors.navyOpacity(0.08),
    borderRadius: 8,
  },
  pdfBtnText: {
    fontSize: 13,
    fontWeight: '500',
    color: Colors.navy,
  },
  // Empty state
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
  },
  emptyTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.navy,
    marginTop: 16,
  },
  emptyMessage: {
    fontSize: 14,
    color: Colors.navyOpacity(0.6),
    textAlign: 'center',
    marginTop: 8,
  },
});
